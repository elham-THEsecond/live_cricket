import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/channel.dart';
import '../models/stream_data.dart';
import '../services/stream_service.dart';

enum StreamState { idle, loading, success, error, empty }

class StreamsProvider extends ChangeNotifier {
  final StreamService _service;

  StreamState _state = StreamState.idle;
  StreamData? _streamData;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  String _searchQuery = '';

  StreamsProvider({String? baseUrl})
      : _service = StreamService(baseUrl: baseUrl ?? AppConstants.apiBaseUrl);

  StreamState get state => _state;
  StreamData? get streamData => _streamData;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchTime => _lastFetchTime;
  bool get isLoading => _state == StreamState.loading;
  bool get hasError => _state == StreamState.error;
  bool get isEmpty => _state == StreamState.empty;
  String get searchQuery => _searchQuery;

  /// All channels from the last successful fetch, unfiltered.
  List<Channel> get allChannels => _streamData?.channels ?? const [];

  /// Channels after the search filter is applied.
  List<Channel> get channels {
    if (_searchQuery.isEmpty) return allChannels;
    final q = _searchQuery.toLowerCase();
    return allChannels.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  Future<void> fetchStreams() async {
    if (_state == StreamState.loading) return;
    _state = StreamState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _service.fetchStreams();
      _streamData = data;
      _lastFetchTime = DateTime.now();
      _state = data.channels.isEmpty ? StreamState.empty : StreamState.success;
    } on StreamServiceException catch (e) {
      _errorMessage = e.message;
      _state = StreamState.error;
    } catch (e) {
      _errorMessage = e.toString();
      _state = StreamState.error;
    }
    notifyListeners();
  }

  /// Fetches fresh data from the backend, then triggers a server-side refresh.
  /// The refresh is best-effort: a failure there must not discard good data.
  Future<void> refresh() async {
    await fetchStreams();
    if (_state == StreamState.error) return;
    try {
      await _service.refreshStreams();
    } on StreamServiceException {
      // Ignored: we already have usable data.
    }
  }

  void filterChannels(String query) {
    final next = query.trim();
    if (next == _searchQuery) return;
    _searchQuery = next;
    notifyListeners();
  }

  Channel? getChannelById(String id) {
    for (final c in allChannels) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Returns to the last successful data if we have it, otherwise idle.
  void clearError() {
    if (_state != StreamState.error) return;
    _state = _streamData == null
        ? StreamState.idle
        : (_streamData!.channels.isEmpty
            ? StreamState.empty
            : StreamState.success);
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}