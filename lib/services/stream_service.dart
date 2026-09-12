import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/stream_data.dart';

class StreamService {
  final String baseUrl;
  final http.Client _client;

  StreamService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Fetches all cricket streams from the backend.
  /// Throws [StreamServiceException] on any failure.
  Future<StreamData> fetchStreams() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl${AppConstants.streamsEndpoint}'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw StreamServiceException(
          'Server returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      // A valid-JSON-but-wrong-shape body (e.g. a bare list) would otherwise
      // surface as a TypeError, which isn't a FormatException.
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return StreamData.fromJson(decoded);
    } on StreamServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw StreamServiceException('Network error: ${e.message}');
    } on TimeoutException {
      throw StreamServiceException('Request timed out');
    } on FormatException {
      throw StreamServiceException('Invalid data from server');
    }
  }

  /// Triggers a manual refresh on the backend.
  Future<void> refreshStreams() async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl${AppConstants.refreshEndpoint}'))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw StreamServiceException(
          'Refresh failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on StreamServiceException {
      rethrow;
    } on http.ClientException catch (e) {
      throw StreamServiceException('Network error: ${e.message}');
    } on TimeoutException {
      throw StreamServiceException('Refresh timed out');
    }
  }

  void dispose() => _client.close();
}

class StreamServiceException implements Exception {
  final String message;
  final int? statusCode;

  StreamServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}