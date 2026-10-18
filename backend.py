#!/usr/bin/env python3
"""Backend for cricket_stream_finder. Stdlib only.

    python3 backend.py            # serves on 0.0.0.0:8000
    curl localhost:8000/api/streams

Channels come from the iptv-org index (https://iptv-org.github.io/api/),
filtered to cricket channels, cached in backend_cache.json. LOCAL_CHANNELS
overrides/adds entries that iptv-org can't represent (user-supplied URLs).
Cache refreshes once per day (RFC-9111 max-age, stale-while-revalidate);
POST /api/refresh forces it.
"""
import json
import os
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# ponytail: user-supplied channels iptv-org can't carry (geo-restricted,
# DRM-free feeds from other sources, custom m3u8s). Add entries with the
# same schema as iptv streams; they override same-id iptv channels.
LOCAL_CHANNELS = []

CACHE_FILE = "backend_cache.json"
CACHE_MAX_AGE = 24 * 60 * 60  # seconds

# Channels known to carry cricket. iptv-org names these "sports" channels;
# whitelisting by id keeps the list stable and avoids TV-show false positives.
CRICKET_IDS = {
    "Willow.us", "WillowSports.us", "WillowXtra.us",
    "SonySportsTen1.in", "SonySportsTen2.in", "SonySportsTen3Hindi.in",
    "SonySportsTen4.in", "SonySportsTen5.in", "TenCricket.in",
    "StarSports1.in", "StarSports2.in", "StarSportsSelect1.in",
    "PTVSports.pk", "ASports.pk", "SkySportsCricket.uk", "SkySportsCricket.ie",
    "FoxCricket.au", "AstroCricket.my", "CricketGold.au",
    "SuperSportCricket.za", "WataniaSports.tn", "HimalayaSportsHD.np",
    "AfricaSportsTV.fr",
}

API_CHANNELS = "https://iptv-org.github.io/api/channels.json"
API_STREAMS = "https://iptv-org.github.io/api/streams.json"


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "cricket-stream-finder"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def fetch_iptv():
    """Fetch iptv-org channels+streams, return dict {channel_id: channel}."""
    channels = {c["id"]: c for c in fetch_json(API_CHANNELS)}
    streams = fetch_json(API_STREAMS)
    by_channel = {}
    for s in streams:
        cid = s.get("channel")
        if cid in CRICKET_IDS:
            by_channel.setdefault(cid, []).append(s)

    out = {}
    for cid in CRICKET_IDS:
        c = channels.get(cid)
        if not c:
            continue
        st = by_channel.get(cid, [])
        out[cid] = {
            "id": cid,
            "name": c["name"],
            "alt_names": c.get("alt_names") or [],
            "country": c.get("country") or "",
            "logo": c.get("logo") or "",
            "streams": [iptv_stream(s) for s in st],
        }
    return out


# Hosts that 403 without a browser-like UA. iptv-org's data rarely carries
# one, so fall back per host — verified 2026-09: cloudplay-sonyliv (Sony
# Sports Ten mirrors) rejects curl/urllib but serves with this UA+referer.
MOBILE_UA = ("Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 "
             "(KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36")
HOST_HEADERS = {
    "cloudplay-sonyliv.pages.dev": (MOBILE_UA, "https://sonyliv.com/"),
    "leaf.highfly.dev": (MOBILE_UA, ""),  # may 404 when offline; app falls through
}


def iptv_stream(s):
    ua, ref = HOST_HEADERS.get(urllib.parse.urlparse(s["url"]).netloc, ("", ""))
    return {
        "url": s["url"],
        "referrer": s.get("referrer") or ref,
        "user_agent": s.get("user_agent") or ua,
        "status": "live",
        "validated": datetime.now(timezone.utc).isoformat(),
    }


def load_channels():
    """Merge iptv-org channels with LOCAL_CHANNELS (local wins per id)."""
    merged = {c["id"]: c for c in LOCAL_CHANNELS}
    merged.update(fetch_iptv())
    return list(merged.values())


_refresh_lock = threading.Lock()
_refreshing = False


def serve_payload():
    """Serve cached (possibly stale) data immediately; refresh in background.

    A live iptv-org fetch takes ~30s; doing it inline in the request handler
    made the first GET after cache expiry block for that long (measured 33s).
    Only a true cold start (no cache file) fetches inline, since there is
    nothing to serve yet.
    """
    global _refreshing
    if _stale():
        if os.path.exists(CACHE_FILE):
            with _refresh_lock:
                if not _refreshing:
                    _refreshing = True
                    threading.Thread(target=_background_refresh, daemon=True).start()
        else:
            # shortcut: cold start still fetches inline and can duplicate
            # fetches under simultaneous first requests; upgrade if that hurts
            try:
                _write_cache(load_channels())
            except (urllib.error.URLError, OSError, ValueError, KeyError):
                pass
    return _cached()


def _background_refresh():
    global _refreshing
    try:
        _write_cache(load_channels())
    except (urllib.error.URLError, OSError, ValueError, KeyError):
        # offline: keep serving last-known-good cache
        pass
    finally:
        with _refresh_lock:
            _refreshing = False


def _stale():
    try:
        return time.time() - _cache_meta()["ts"] > CACHE_MAX_AGE
    except FileNotFoundError:
        return True


def _cache_meta():
    with open(CACHE_FILE) as f:
        head = json.load(f)
    return head


def _cached():
    with open(CACHE_FILE) as f:
        head = json.load(f)
    # Channels with no live streams would render as tappable dead tiles in
    # the app (firstStreamUrl throws) — drop them; they reappear on refresh.
    channels = [c for c in head["channels"] if c["streams"]]
    streams = sum(len(c["streams"]) for c in channels)
    return {
        "generated_at": datetime.fromtimestamp(head["ts"], timezone.utc).isoformat(),
        "total_channels": len(channels),
        "total_streams": streams,
        "channels": channels,
    }


def _write_cache(channels):
    tmp = CACHE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"ts": time.time(), "channels": channels}, f, indent=1)
    os.replace(tmp, CACHE_FILE)


class Handler(BaseHTTPRequestHandler):
    def _send(self, body, status=200):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/api/streams":
            try:
                self._send(serve_payload())
            except FileNotFoundError:
                self._send({"error": "not ready: first fetch failed"}, 503)
        else:
            self._send({"error": "not found"}, 404)

    def do_POST(self):
        if self.path == "/api/refresh":
            try:
                _write_cache(load_channels())
                self._send({"ok": True})
            except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
                self._send({"ok": False, "error": str(e)}, 502)
        else:
            self._send({"error": "not found"}, 404)

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))  # Render/Railway inject PORT
    print(f"serving on http://0.0.0.0:{port}  (GET /api/streams, POST /api/refresh)")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
