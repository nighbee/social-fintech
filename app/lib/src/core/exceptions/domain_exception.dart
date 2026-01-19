sealed class DomainException implements Exception {
  DomainException({required this.message, this.stackTrace});
  String message;
  StackTrace? stackTrace;

  @override
  String toString() {
    String message = this.message;
    return 'Exception: $message';
  }
}

class UnknownException extends DomainException {
  UnknownException({String? message, super.stackTrace})
    : super(message: message ?? 'Unknown Exception');
}

class BadRequest extends DomainException {
  BadRequest({super.stackTrace}) : super(message: 'Bad Request');
}

class UnknownError extends DomainException {
  UnknownError() : super(message: 'Unknown Error');
}

class NoInternetConnectionException extends DomainException {
  NoInternetConnectionException()
    : super(message: 'No Internet Connection Exception');
}

class MapperException extends DomainException {
  MapperException() : super(message: 'Mapper Exception');
}

class NetworkException extends DomainException {
  NetworkException({required super.message, super.stackTrace});
}

class GoogleSignInException extends DomainException {
  GoogleSignInException({String? message})
    : super(message: message ?? 'Google Sign In Exception');
}

class AppleSignInException extends DomainException {
  AppleSignInException({String? message})
    : super(message: message ?? 'Apple Sign In Exception');
}
