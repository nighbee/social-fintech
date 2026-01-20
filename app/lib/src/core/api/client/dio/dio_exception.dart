import 'package:dio/dio.dart';

class DioExceptions implements Exception {
  late final String message;

  DioExceptions.fromDioError(DioException dioError) {
    message = _handleError(dioError.response?.statusCode);
  }

  String _handleError(int? statusCode) {
    switch (statusCode) {
      default:
        return statusCode == null ? 'Network error' : '$statusCode';
    }
  }

  @override
  String toString() => message;
}
