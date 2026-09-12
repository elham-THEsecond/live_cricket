import 'dart:convert';

import 'package:cricket_stream_finder/models/channel.dart';
import 'package:cricket_stream_finder/models/stream_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the documented API shape and drops dead streams', () {
    final data = StreamData.fromJson(jsonDecode('''
    {
      "generated_at": "2025-01-15T10:30:00Z",
      "total_channels": 2,
      "total_streams": 2,
      "channels": [
        {
          "id": "SonyTEN1.in",
          "name": "Sony TEN 1",
          "alt_names": ["Sony Ten 1 HD"],
          "country": "IN",
          "logo": "https://example.com/logo.png",
          "streams": [
            {"url": "https://example.com/a.m3u8", "referrer": "",
             "user_agent": "", "status": "live",
             "validated": "2025-01-15T10:29:45Z"},
            {"url": "https://example.com/dead.m3u8", "status": "dead"}
          ]
        },
        {
          "id": "Offline.in",
          "name": "Offline Channel",
          "country": "IN",
          "streams": [{"url": "https://example.com/x.m3u8", "status": "dead"}]
        }
      ]
    }
    ''') as Map<String, dynamic>);

    // Dead stream dropped from the surviving channel.
    expect(data.channels.length, 1);
    expect(data.channels.single.streams.length, 1);
    expect(data.channels.single.firstStreamUrl, 'https://example.com/a.m3u8');
    expect(data.channels.single.altNames, ['Sony Ten 1 HD']);
    expect(data.channels.single.hasLiveStreams, isTrue);
    expect(data.generatedAt, DateTime.utc(2025, 1, 15, 10, 30));
  });

  test('survives missing and malformed fields', () {
    final channel = Channel.fromJson({'id': 'x', 'streams': 'not-a-list'});
    expect(channel.name, '');
    expect(channel.streams, isEmpty);
    expect(channel.hasLiveStreams, isFalse);
  });
}