import 'package:fpdart/fpdart.dart';

import '../../exceptions/domain_exception.dart';
import '../../utils/loggers/log.dart';
import '../base_models/base_request.dart';
import 'result.dart';

/// How to call use case and use it:
/// final result = await _useCase();
/// if (result.isSuccessful && result.data != null) {
///    do something
/// }

/// This class describes a base class for use cases. You have to use its
/// in cases when you have incoming and outgoing data.
/// [R] - a type of a result data
/// [Input] - a type of a incoming data
abstract class UseCase<R, Request extends BaseRequest> {
  // final IsolateManager _isolateManager = getIt<IsolateManager>();
  Future<Result<R, DomainException>> call(
    Request requestModel, {
    bool useIsolate = false,
  }) async {
    final Either<DomainException, R> result =
        // useIsolate
        //     ? await _isolateManager
        //         .methodExecute<Either<DomainException, R>, Request>(
        //         requestModel,
        //         execute,
        //       )
        //     :
        await execute(requestModel);

    return result.fold(
      (DomainException error) {
        Log.e(error.toString());
        return Result.failure(error);
      },
      (insertData) => Result.success(insertData),
    );
  }

  Future<Either<DomainException, R>> execute(Request requestModel);
}

/// This class describes a base class for use cases. You have to use its
/// in cases when you have only outgoing data.
/// [R] - a type of a result data
abstract class NoneInputBoundaryUseCase<R> {
  // final IsolateManager _isolateManager = getIt<IsolateManager>();
  Future<Result<R, DomainException>> call({bool useIsolate = false}) async {
    final Either<DomainException, R> result =
        // useIsolate
        //     ? await _isolateManager
        //         .noneInputMethodExecute<Either<DomainException, R>>(execute)
        //     :
        await execute();

    return result.fold(
      (DomainException error) {
        Log.e(error.toString());
        return Result.failure(error);
      },
      (insertData) => Result.success(insertData),
    );
  }

  Future<Either<DomainException, R>> execute();
}

/// This class describes a base class for use cases. You have to use its
/// in cases when you have only outgoing data.
/// [Input] - a type of a incoming data
abstract class NoneOutputBoundaryUseCase<Request extends BaseRequest> {
  // final IsolateManager _isolateManager = getIt<IsolateManager>();
  Future<Result<void, DomainException>> call(
    Request requestModel, {
    bool useIsolate = false,
  }) async {
    final Either<DomainException, void> result =
        //  useIsolate
        //     ? await _isolateManager
        //         .methodExecute<Either<DomainException, void>, Request>(
        //         requestModel,
        //         execute,
        //       )
        // :
        await execute(requestModel);
    return result.fold(
      (DomainException error) {
        Log.e(error.toString());
        return Result.failure(error);
      },
      (insertData) => Result.success(insertData),
    );
  }

  Future<Either<DomainException, void>> execute(Request requestModel);
}

/// This class describes a base class for use cases. You have to use its
/// in cases when you don't have outgoing and incoming data.
abstract class NoneInputOutputBoundaryUseCase {
  // final IsolateManager _isolateManager = getIt<IsolateManager>();
  Future<Result<void, DomainException>> call({bool useIsolate = false}) async {
    final Either<DomainException, void> result =
        //  useIsolate
        //     ? await _isolateManager
        //         .noneInputMethodExecute<Either<DomainException, void>>(execute)
        //     :
        await execute();
    return result.fold(
      (DomainException error) {
        Log.e(error.toString());
        return Result.failure(error);
      },
      (insertData) => Result.success(insertData),
    );
  }

  Future<Either<DomainException, void>> execute();
}

abstract class BaseStreamUseCase<R, Request extends BaseRequest> {
  Stream<Result<R, DomainException>> call(Request requestModel) async* {
    final Stream<Either<DomainException, R>> stream = execute(requestModel);
    yield* stream.map((Either<DomainException, R> result) {
      return result.fold(
        (DomainException error) {
          Log.e(error.toString());
          return Result.failure(error);
        },
        (insertData) => Result.success(insertData),
      );
    });
  }

  Stream<Either<DomainException, R>> execute(Request requestModel);
}

abstract class NoneInputStreamUseCase<R> {
  Stream<Result<R, DomainException>> call() async* {
    final Stream<Either<DomainException, R>> stream = execute();
    yield* stream.map((Either<DomainException, R> result) {
      return result.fold(
        (DomainException error) {
          Log.e(error.toString());
          return Result.failure(error);
        },
        (insertData) => Result.success(insertData),
      );
    });
  }

  Stream<Either<DomainException, R>> execute();
}
