import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:app/src/core/api/client/dio/dio_exception.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/utils/loggers/log.dart';

import 'rest_client.dart';

part 'dio_config.dart';

abstract class DioRestClient implements RestClient {
  late final Dio dio;

  @override
  void setBaseUrl({
    required String ipAddress,
    int? port,
  }) {
    try {
      if (port != null) {
        dio.options = dio.options.copyWith(baseUrl: '$ipAddress:$port');
      } else {
        dio.options = dio.options.copyWith(baseUrl: ipAddress);
      }
      Log.debug('DioRestClient', 'dio: ${dio.options.baseUrl}');
    } catch (e) {
      dio.options = dio.options.copyWith(baseUrl: '');
      Log.error('DioRestClient', 'Error setting baseUrl');
    }
  }

  @override
  Future<Either<DomainException, Response>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final Response response = await dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return Right(response);
    } catch (e, st) {
      return Left(_handleError(e, st));
    }
  }

  @override
  Future<Either<DomainException, Response>> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final Response response = await dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return Right(response);
    } catch (e, st) {
      return Left(_handleError(e, st));
    }
  }

  @override
  Future<Either<DomainException, Response>> put(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final Response response = await dio.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return Right(response);
    } catch (e, st) {
      return Left(_handleError(e, st));
    }
  }

  @override
  Future<Either<DomainException, Response>> delete(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final Response response = await dio.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return Right(response);
    } catch (e, st) {
      return Left(_handleError(e, st));
    }
  }

  @override
  Future<Either<DomainException, Response>> patch(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response response = await dio.patch(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return Right(response);
    } catch (e, st) {
      return Left(_handleError(e, st));
    }
  }

  DomainException _handleError(Object e, StackTrace st) {
    if (e is DioException) {
      return _handleDioException(e, st);
    }
    return UnknownException();
  }

  DomainException _handleDioException(
    DioException e,
    StackTrace st,
  ) {
    final String errorMessage = DioExceptions.fromDioError(e).toString();
    return NetworkException(message: errorMessage, stackTrace: st);
  }
}
