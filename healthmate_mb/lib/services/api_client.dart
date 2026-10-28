import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/app_config.dart';

enum ApiErrorType {
  notConfigured,
  network,
  timeout,
  rateLimit,
  unauthorized,
  server,
  invalidResponse,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;

  const ApiException(this.type, this.message, {this.statusCode});

  bool get isRetryable =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.server ||
      type == ApiErrorType.rateLimit;

  @override
  String toString() => message;
}

/// Thin HTTP client with timeouts, bounded retries and safe error mapping.
/// It never logs URLs that could contain user location or tokens.
class ApiClient {
  final http.Client _client;
  final String baseUrl;

  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.proxyBaseUrl;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return base.resolve(normalized).replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 15),
    int retries = 1,
  }) async {
    if (!isConfigured) {
      throw const ApiException(
        ApiErrorType.notConfigured,
        'The HealthMate data service is not configured.',
      );
    }

    ApiException? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _client.get(uri(path, query)).timeout(timeout);
        final decoded = _decode(response);
        return decoded;
      } on TimeoutException {
        lastError = const ApiException(
          ApiErrorType.timeout,
          'The request timed out. Check your connection and try again.',
        );
      } on ApiException catch (error) {
        lastError = error;
        if (!error.isRetryable) rethrow;
      } catch (_) {
        lastError = const ApiException(
          ApiErrorType.network,
          'Could not reach the HealthMate data service. Check your connection.',
        );
      }

      if (attempt < retries) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }
    throw lastError ??
        const ApiException(ApiErrorType.network, 'The request failed.');
  }

  Map<String, dynamic> _decode(http.Response response) {
    final status = response.statusCode;
    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Fall through to a typed error below.
      }
    }

    if (status >= 200 && status < 300) {
      if (body == null) {
        throw const ApiException(
          ApiErrorType.invalidResponse,
          'The data service returned an unreadable response.',
        );
      }
      return body;
    }

    final serverMessage = body?['error'] is Map
        ? (body!['error']['message']?.toString() ?? '')
        : '';
    switch (status) {
      case 401:
      case 403:
        throw ApiException(
          ApiErrorType.unauthorized,
          serverMessage.isNotEmpty
              ? serverMessage
              : 'The data service rejected this request.',
          statusCode: status,
        );
      case 429:
        throw ApiException(
          ApiErrorType.rateLimit,
          serverMessage.isNotEmpty
              ? serverMessage
              : 'Too many requests. Please wait a moment and try again.',
          statusCode: status,
        );
      case 400:
      case 404:
      case 422:
        throw ApiException(
          ApiErrorType.invalidResponse,
          serverMessage.isNotEmpty ? serverMessage : 'The request was not valid.',
          statusCode: status,
        );
      default:
        throw ApiException(
          ApiErrorType.server,
          serverMessage.isNotEmpty
              ? serverMessage
              : 'The data service is temporarily unavailable.',
          statusCode: status,
        );
    }
  }

  void close() => _client.close();
}
