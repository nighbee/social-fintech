import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/config/environment_manager.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/secure_storage/secure_storage_service_impl.dart';
import 'package:app/src/core/utils/loggers/log.dart';

class TokenInterceptor extends Interceptor {
  final ISecureStorageService storage;
  final Dio dio;

  TokenInterceptor({required this.dio}) : storage = SecureStorageServiceImpl();

  bool _isRefreshing = false;
  final Queue<Future Function()> _refreshQueue = Queue();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Public endpoints that don't require authentication
    const publicPaths = [
      '/auth/login',
      '/auth/register-email',
      '/auth/login-email',
      '/auth/phone/request',
      '/auth/phone/verify',
      '/auth/register-phone',
    ];

    final isPublicPath = publicPaths.any((path) => options.path.contains(path));

    // Don't add token to public endpoints
    if (!isPublicPath) {
      final accessToken = await storage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final accessToken = await storage.getAccessToken();

    // Public endpoints that don't require authentication
    const publicPaths = [
      '/auth/login',
      '/auth/register-email',
      '/auth/login-email',
      '/auth/phone/request',
      '/auth/phone/verify',
      '/auth/register-phone',
    ];

    final isPublicPath = publicPaths.any(
      (path) => err.requestOptions.path.contains(path),
    );

    if (err.response?.statusCode == 401 && isPublicPath) {
      return handler.next(err);
    }

    if (err.response?.statusCode == 401 &&
        accessToken != null &&
        accessToken.isNotEmpty) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          await _refreshToken();
          final response = await _retry(err.requestOptions);
          await _processRefreshQueue();
          _isRefreshing = false;
          return handler.resolve(response);
        } catch (e) {
          _isRefreshing = false;
          await _handleRefreshError(e, err.requestOptions, handler);
        }
      } else {
        final responseCompleter = Completer<Response>();
        _refreshQueue.add(() async {
          try {
            final response = await _retry(err.requestOptions);
            responseCompleter.complete(response);
          } catch (e) {
            responseCompleter.completeError(e);
          }
        });
        return handler.resolve(await responseCompleter.future);
      }
    }
    handler.next(err);
  }

  Future<void> _refreshToken() async {
    final refreshToken = await storage.getRefreshToken();
    Log.debug('TokenInterceptor', 'Refreshing token: $refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No refresh token available');
    }

    final EnvironmentManager envManager = getIt<EnvironmentManager>();
    final Dio dioInstance = Dio(BaseOptions(baseUrl: envManager.baseUrl));

    try {
      final Response<dynamic> result = await dioInstance.post(
        EndPoints.authRefresh,
        data: {'refresh_token': refreshToken},
        options: Options(contentType: Headers.jsonContentType),
      );

      Log.debug(
        'TokenInterceptor',
        'Refresh request: URL=${EndPoints.authRefresh}, payload=${result.requestOptions.data}',
      );

      // Parse response - adjust based on your actual response structure
      final data = result.data;
      if (data is Map<String, dynamic>) {
        final accessToken = data['access_token'] as String?;
        final refreshTokenNew = data['refresh_token'] as String?;

        if (accessToken != null) {
          await storage.setAccessToken(accessToken);
        }
        if (refreshTokenNew != null) {
          await storage.setRefreshToken(refreshTokenNew);
        }
        Log.debug('TokenInterceptor', 'Token refresh success');
      }
    } catch (e) {
      Log.debug('TokenInterceptor', 'Token refresh error: $e');
      rethrow;
    }
  }

  Future<Response> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<void> _processRefreshQueue() async {
    while (_refreshQueue.isNotEmpty) {
      await _refreshQueue.removeFirst()();
    }
  }

  Future<void> _handleRefreshError(
    dynamic error,
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
  ) async {
    Log.debug('TokenInterceptor', 'Handling refresh error: $error');
    await _clearTokens();
    _refreshQueue.clear();

    // Navigate to auth screen
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go(RoutePaths.auth);
    }

    handler.next(
      DioException(
        requestOptions: requestOptions,
        error: 'Token refresh failed: $error',
      ),
    );
  }

  Future<void> _clearTokens() async {
    await storage.deleteAccessToken();
    await storage.deleteRefreshToken();
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
}
