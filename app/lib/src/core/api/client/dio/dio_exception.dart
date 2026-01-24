import 'package:dio/dio.dart';
import 'package:app/src/core/utils/loggers/log.dart';

class DioExceptions implements Exception {
  late final String message;

  DioExceptions.fromDioError(DioException dioError) {
    message = _handleError(dioError);
  }

  String _handleError(DioException dioError) {
    // Log the full error for debugging
    Log.error(
      'DioExceptions',
      'Status Code: ${dioError.response?.statusCode}, '
          'Message: ${dioError.message}, '
          'Response Data: ${dioError.response?.data}',
    );

    final statusCode = dioError.response?.statusCode;

    // Try to extract error message from response body
    String? errorMessage;
    if (dioError.response?.data != null) {
      try {
        final data = dioError.response!.data;
        if (data is Map<String, dynamic>) {
          // Try common error message fields
          errorMessage =
              data['message'] as String? ??
              data['error'] as String? ??
              data['detail'] as String?;
          // If there's a nested errors object
          if (errorMessage == null && data['errors'] != null) {
            final errors = data['errors'];
            if (errors is Map) {
              // Get first error message
              final firstError = errors.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                errorMessage = firstError.first.toString();
              } else if (firstError is String) {
                errorMessage = firstError;
              }
            }
          }
        } else if (data is String) {
          errorMessage = data;
        }
      } catch (e) {
        Log.error('DioExceptions', 'Failed to parse error message: $e');
      }
    }

    // Return extracted message or fallback to status code
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return errorMessage;
    }
    // Fallback to status code based messages
    switch (statusCode) {
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 500:
        return 'Internal Server Error';
      default:
        return statusCode == null
            ? 'Network error: ${dioError.message}'
            : 'Error $statusCode';
    }
  }

  @override
  String toString() => message;
}
