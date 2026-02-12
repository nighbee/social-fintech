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
  DioClient() {
    final environmentManager = getIt<EnvironmentManager>();
    final appStorage = AppStorageImpl();
    final BaseOptions options = BaseOptions(
      baseUrl: environmentManager.baseUrl,
      contentType: Headers.jsonContentType,
      connectTimeout: DioConfigurations.connectTimeout,
      receiveTimeout: DioConfigurations.receiveTimeout,
      sendTimeout: DioConfigurations.sendTimeout,
      headers: {'Accept-Language': appStorage.getLocale()},
    );
    Log.debug('DioClient', 'baseUrl: ${environmentManager.baseUrl}');
    dio = Dio(options);

    // Add token interceptor BEFORE other interceptors
    dio.interceptors.add(TokenInterceptor(dio: dio));

    _addTalkerInterceptor();
  }

  void _addTalkerInterceptor() {
    try {
      dio.interceptors.add(getIt<TalkerDioLogger>());
      Log.debug('DioClient', 'TalkerDioLogger added successfully');
    } catch (e) {
      // TalkerDioLogger not available yet, will be added later
      Log.debug('DioClient', 'TalkerDioLogger not available: $e');
    }
  }

  @override
  late final Dio dio;
}
