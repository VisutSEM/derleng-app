import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio that attaches the bearer token and turns transport
/// and Laravel validation errors into [ApiException]s the UI can display.
class ApiClient {
  ApiClient({
    required String baseUrl,
    this.tokenProvider,
  }) : _baseUrl = _normalize(baseUrl) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: AppConfig.requestTimeout,
        receiveTimeout: AppConfig.requestTimeout,
        sendTimeout: AppConfig.requestTimeout,
        headers: const {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  final String _baseUrl;
  final String? Function()? tokenProvider;

  String get baseUrl => _baseUrl;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> post(String path, {Object? data}) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> put(String path, {Object? data}) async {
    try {
      final response = await _dio.put<dynamic>(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> patch(String path, {Object? data}) async {
    try {
      final response = await _dio.patch<dynamic>(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete<dynamic>(path);
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  /// Lightweight connectivity check used by the Profile tab.
  Future<Duration> ping() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _dio.get<dynamic>(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return stopwatch.elapsed;
    } on DioException catch (error) {
      throw _mapError(error);
    } finally {
      stopwatch.stop();
    }
  }

  static String _normalize(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) trimmed = AppConfig.apiBaseUrl;
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.endsWith('/api')) {
      trimmed = '$trimmed/api';
    }
    return trimmed;
  }

  static ApiException _mapError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException.network();
      case DioExceptionType.badCertificate:
        return const ApiException('The API certificate could not be verified.');
      case DioExceptionType.cancel:
        return const ApiException('Request cancelled.');
      case DioExceptionType.badResponse:
        break;
      case DioExceptionType.unknown:
        if (error.error is FormatException) {
          return const ApiException('The API returned an unexpected response.');
        }
        return ApiException.network();
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;
    var message = 'Something went wrong. Please try again.';

    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          message = '${first.first}';
        } else if (first != null) {
          message = '$first';
        }
      } else if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        message = data['message'] as String;
      }
    } else if (data is String && data.trim().isNotEmpty && data.length < 180) {
      message = data.trim();
    }

    if (status == 401) {
      message = 'Your session expired. Please sign in again.';
    } else if (status == 403) {
      message = 'You do not have access to this resource.';
    } else if (status == 404) {
      message = 'The requested resource was not found.';
    } else if (status != null && status >= 500) {
      message = 'The Derleng API is unavailable right now.';
    }

    return ApiException(message, statusCode: status);
  }
}
