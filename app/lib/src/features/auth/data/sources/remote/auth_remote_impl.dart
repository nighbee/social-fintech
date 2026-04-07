import 'dart:developer';
import 'dart:io';

import 'package:app/src/features/auth/data/models/user_search_dto.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/utils/device_id.dart';
import 'package:app/src/core/utils/loggers/log.dart';
import 'package:app/src/features/auth/data/models/login_dto.dart';
import 'package:app/src/features/auth/data/models/phone_code_response_dto.dart';
import 'package:app/src/features/auth/data/sources/remote/i_auth_remote.dart';

@named
@LazySingleton(as: IAuthRemote)
class AuthRemoteImpl implements IAuthRemote {
  AuthRemoteImpl(@Named('DioClient') this._client);

  final RestClient _client;
  final DeviceId _deviceId = DeviceId();

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
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final appVersion = await _getAppVersion();
    final userAgent = _getUserAgent();

    final result = await _client.post(
      EndPoints.authLogin,
      data: {
        'provider_type': 'google',
        'provider_token': providerToken,
        'device_id': deviceId,
        'user_agent': userAgent,
        'app_version': appVersion,
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
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final appVersion = await _getAppVersion();
    final userAgent = _getUserAgent();

    final result = await _client.post(
      EndPoints.authLogin,
      data: {
        'provider_type': 'apple',
        'provider_token': providerToken,
        'device_id': deviceId,
        'user_agent': userAgent,
        'app_version': appVersion,
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
  Future<Either<DomainException, bool>> checkEmailExists({
    required String email,
  }) async {
    final result = await _client.post(
      EndPoints.authCheckEmail,
      data: {'email': email},
    );

    return result.fold((error) => Left(error), (response) {
      try {
        final exists = response.data['exists'] as bool;
        return Right(exists);
      } catch (e) {
        return Left(NetworkException(message: 'Failed to parse response: $e'));
      }
    });
  }

  @override
  Future<Either<DomainException, LoginDto>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final appVersion = await _getAppVersion();
    final userAgent = _getUserAgent();

    final requestData = {
      'email': email,
      'password': password,
      'device_id': deviceId,
      'app_version': appVersion,
      'user_agent': userAgent,
    };

    log('=== LOGIN EMAIL REQUEST ===');
    log('URL: ${EndPoints.authLoginEmail}');
    log('Email: $email');
    log('Password: $password');
    log('Data: $requestData');
    log('===========================');

    final result = await _client.post(
      EndPoints.authLoginEmail,
      data: requestData,
    );

    return result.fold(
      (error) {
        log('=== LOGIN EMAIL ERROR ===');
        log('Error: ${error.message}');
        log('Error type: ${error.runtimeType}');
        log('=========================');
        Log.error('AuthRemote', 'Login Email Error: ${error.message}');
        return Left(error);
      },
      (response) {
        log('=== LOGIN EMAIL SUCCESS ===');
        log('Response: ${response.data}');
        log('===========================');
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
    required String dateOfBirth,
    String? referral,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
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
      if ((referral ?? '').trim().isNotEmpty)
        'referrer_user_id': referral!.trim(),
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
  }) async {
    final deviceId = await _deviceId.getDeviceId();
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
    required String dateOfBirth,
    String? referral,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final result = await _client.post(
      EndPoints.authRegisterPhone,
      data: {
        'verification_id': verificationId,
        'first_name': firstName,
        'last_name': lastName,
        'device_id': deviceId,
        'date_of_birth': dateOfBirth,
        if ((referral ?? '').trim().isNotEmpty)
          'referrer_user_id': referral!.trim(),
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

  @override
  Future<Either<DomainException, LoginDto>> firebasePhoneLogin({
    required String firebaseIdToken,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final appVersion = await _getAppVersion();
    final userAgent = _getUserAgent();

    final result = await _client.post(
      EndPoints.authFirebasePhoneLogin,
      data: {
        'firebase_id_token': firebaseIdToken,
        'device_id': deviceId,
        'app_version': appVersion,
        'user_agent': userAgent,
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
  Future<Either<DomainException, LoginDto>> firebasePhoneRegister({
    required String firebaseIdToken,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    String? referral,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final appVersion = await _getAppVersion();
    final userAgent = _getUserAgent();

    final requestData = {
      'firebase_id_token': firebaseIdToken,
      'first_name': firstName,
      'last_name': lastName,
      'device_id': deviceId,
      'app_version': appVersion,
      'user_agent': userAgent,
      'date_of_birth': dateOfBirth,
      if ((referral ?? '').trim().isNotEmpty)
        'referrer_user_id': referral!.trim(),
    };

    final result = await _client.post(
      EndPoints.authFirebasePhoneRegister,
      data: requestData,
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
  Future<Either<DomainException, List<UserSearchDto>>> searchUsers({
    required String firstName,
    required String lastName,
    int limit = 20,
  }) async {
    final result = await _client.get(
      EndPoints.usersSearch,
      queryParameters: {
        'first_name': firstName,
        'last_name': lastName,
        'limit': limit,
      },
    );

    return result.fold((error) => Left(error), (response) {
      try {
        final List<dynamic> jsonList = response.data;
        final users =
            jsonList.map((json) => UserSearchDto.fromJson(json)).toList();
        return Right(users);
      } catch (e) {
        return Left(
          NetworkException(message: 'Failed to parse response: $e'),
        );
      }
    });
  }
}
