import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import 'package:app/src/core/api/client/dio/dio_rest_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/interceptors/token_interceptor.dart';
import 'package:app/src/core/config/environment_manager.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/utils/loggers/log.dart';

@named
@LazySingleton(as: RestClient)
class DioClient extends DioRestClient implements RestClient {
  DioClient(this._environmentManager) {
    final appStorage = AppStorageImpl();
    final BaseOptions options = BaseOptions(
      baseUrl: _environmentManager.baseUrl,
      contentType: Headers.jsonContentType,
      connectTimeout: DioConfigurations.connectTimeout,
      receiveTimeout: DioConfigurations.receiveTimeout,
      sendTimeout: DioConfigurations.sendTimeout,
      headers: {'Accept-Language': appStorage.getLocale()},
    );
    Log.debug('DioClient', 'baseUrl: ${_environmentManager.baseUrl}');
    dio = Dio(options);

    // Add token interceptor BEFORE other interceptors
    dio.interceptors.add(TokenInterceptor(dio: dio));

    // Add standard Dio LogInterceptor for console logging
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (obj) {
          Log.debug('Dio', obj.toString());
        },
      ),
    );

    _addTalkerInterceptor();
  }

  final EnvironmentManager _environmentManager;

  void _addTalkerInterceptor() {
    try {
      if (getIt.isRegistered<TalkerDioLogger>()) {
        dio.interceptors.add(getIt<TalkerDioLogger>());
      }
    } catch (e) {
      Log.debug('DioClient', 'TalkerDioLogger not available: $e');
    }
  }

  @override
  late final Dio dio;
}
