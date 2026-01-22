import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/utils/loggers/log.dart';
import 'package:app/src/features/auth/data/models/login_dto.dart';
import 'package:app/src/features/auth/data/models/phone_code_response_dto.dart';
import 'package:app/src/features/auth/data/sources/remote/i_auth_remote.dart';

@named
@LazySingleton(as: IAuthRemote)
class AuthRemoteImpl implements IAuthRemote {
  AuthRemoteImpl(@Named('DioClient') this._client);

  final RestClient _client;

  // Cache for app version
  String? _appVersion;
  String? _userAgent;

  Future<String> _getAppVersion() async {
    if (_appVersion == null) {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
    }
    return _appVersion!;
  }

  String _getUserAgent() {
    if (_userAgent == null) {
      final platform = Platform.isAndroid ? 'Android' : 'iOS';
      _userAgent = '$platform/${Platform.operatingSystemVersion}';
    }
    return _userAgent!;
  }

  @override
  Future<Either<DomainException, LoginDto>> loginWithGoogle({
    required String providerToken,
    required String deviceId,
  }) async {
    final result = await _client.post(
      EndPoints.authLogin,
      data: {
        'provider_type': 'google',
        'provider_token': providerToken,
        'device_id': deviceId,
      },
    );

    return result.fold((error) => Left(error), (response) {
      try {
        final dto = LoginDto.fromJson(response.data);
        return Right(dto);
      } catch (e) {
        return Left(NetworkException(message: 'Failed to parse response: $e'));
      }
    });
  }

  @override
  Future<Either<DomainException, LoginDto>> loginWithApple({
    required String providerToken,
    required String deviceId,
  }) async {
    final result = await _client.post(
      EndPoints.authLogin,
      data: {
        'provider_type': 'apple',
        'provider_token': providerToken,
        'device_id': deviceId,
      },
    );

    return result.fold((error) => Left(error), (response) {
      try {
        final dto = LoginDto.fromJson(response.data);
        return Right(dto);
      } catch (e) {
        return Left(NetworkException(message: 'Failed to parse response: $e'));
      }
    });
  }

  @override
  Future<Either<DomainException, LoginDto>> loginWithEmail({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final appVersion = await _getAppVersion();
    final userAgent = _getUserAgent();

    final requestData = {
      'email': email,
      'password': password,
      'device_id': deviceId,
      'app_version': appVersion,
      'user_agent': userAgent,
    };

    print('=== LOGIN EMAIL REQUEST ===');
    print('URL: ${EndPoints.authLoginEmail}');
    print('Email: $email');
    print('Password: $password');
    print('Data: $requestData');
    print('===========================');

    final result = await _client.post(
      EndPoints.authLoginEmail,
      data: requestData,
    );

    return result.fold(
      (error) {
        print('=== LOGIN EMAIL ERROR ===');
        print('Error: ${error.message}');
        print('Error type: ${error.runtimeType}');
        print('=========================');
        Log.error('AuthRemote', 'Login Email Error: ${error.message}');
        return Left(error);
      },
      (response) {
        print('=== LOGIN EMAIL SUCCESS ===');
        print('Response: ${response.data}');
        print('===========================');
        Log.debug('AuthRemote', 'Login Email Success:');
        Log.debug('AuthRemote', 'Response: ${response.data}');
        try {
          final dto = LoginDto.fromJson(response.data);
          return Right(dto);
        } catch (e) {
          Log.error('AuthRemote', 'Failed to parse response: $e');
          return Left(
            NetworkException(message: 'Failed to parse response: $e'),
          );
        }
      },
    );
  }

  @override
  Future<Either<DomainException, LoginDto>> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String deviceId,
    required String dateOfBirth,
    required String referral,
  }) async {
    final appVersion = await _getAppVersion();
    final userAgent = _getUserAgent();

    final requestData = {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'device_id': deviceId,
      'app_version': appVersion,
      'user_agent': userAgent,
      'date_of_birth': dateOfBirth,
      // 'referral': referral,
    };

    Log.debug('AuthRemote', 'Register Email Request:');
    Log.debug('AuthRemote', 'URL: ${EndPoints.authRegisterEmail}');
    Log.debug('AuthRemote', 'Data: $requestData');

    final result = await _client.post(
      EndPoints.authRegisterEmail,
      data: requestData,
    );

    return result.fold(
      (error) {
        Log.error('AuthRemote', 'Register Email Error: ${error.message}');
        return Left(error);
      },
      (response) {
        Log.debug('AuthRemote', 'Register Email Success:');
        Log.debug('AuthRemote', 'Response: ${response.data}');
        try {
          final dto = LoginDto.fromJson(response.data);
          return Right(dto);
        } catch (e) {
          Log.error('AuthRemote', 'Failed to parse response: $e');
          return Left(
            NetworkException(message: 'Failed to parse response: $e'),
          );
        }
      },
    );
  }

  @override
  Future<Either<DomainException, PhoneCodeResponseDto>> requestPhoneCode({
    required String countryCode,
    required String phoneNumber,
    required String purpose,
  }) async {
    final result = await _client.post(
      EndPoints.authPhoneRequest,
      data: {
        'country_code': countryCode,
        'phone_number': phoneNumber,
        'purpose': purpose,
      },
    );

    return result.fold((error) => Left(error), (response) {
      try {
        final dto = PhoneCodeResponseDto.fromJson(response.data);
        return Right(dto);
      } catch (e) {
        return Left(NetworkException(message: 'Failed to parse response: $e'));
      }
    });
  }

  @override
  Future<Either<DomainException, LoginDto>> verifyPhoneCode({
    required String verificationId,
    required String code,
    required String deviceId,
  }) async {
    final result = await _client.post(
      EndPoints.authPhoneVerify,
      data: {
        'verification_id': verificationId,
        'code': code,
        'device_id': deviceId,
      },
    );

    return result.fold((error) => Left(error), (response) {
      try {
        final dto = LoginDto.fromJson(response.data);
        return Right(dto);
      } catch (e) {
        return Left(NetworkException(message: 'Failed to parse response: $e'));
      }
    });
  }

  @override
  Future<Either<DomainException, LoginDto>> registerWithPhone({
    required String verificationId,
    required String firstName,
    required String lastName,
    required String deviceId,
    String? dateOfBirth,
    String? referral,
  }) async {
    final result = await _client.post(
      EndPoints.authRegisterPhone,
      data: {
        'verification_id': verificationId,
        'first_name': firstName,
        'last_name': lastName,
        'device_id': deviceId,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (referral != null) 'referral': referral,
      },
    );

    return result.fold((error) => Left(error), (response) {
      try {
        final dto = LoginDto.fromJson(response.data);
        return Right(dto);
      } catch (e) {
        return Left(NetworkException(message: 'Failed to parse response: $e'));
      }
    });
  }

  @override
  Future<Either<DomainException, void>> logout() async {
    final result = await _client.post(EndPoints.authLogout);

    return result.fold((error) => Left(error), (_) => const Right(null));
  }
}
