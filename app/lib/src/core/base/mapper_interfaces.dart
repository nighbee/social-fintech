import 'base_models/base_dto.dart';
import 'base_models/base_entity.dart';
import 'base_models/base_request.dart';

abstract class IDtoToEntity<E extends BaseEntity, D extends BaseDto> {
  E map(D dto);
}

abstract class IEntityToDto<E extends BaseEntity, D extends BaseDto> {
  D map(E entity);
}

abstract class IDtoToResponse<R, D extends BaseDto> {
  R? map(D dto);
}

abstract class IRequestToResponse<R, Request extends BaseRequest> {
  R? map(Request request);
}

abstract class IRequestToDtor<D extends BaseDto, Request extends BaseRequest> {
  D map(Request request);
}

abstract class IRequestToDto<D extends BaseDto, Request extends BaseRequest> {
  D map(Request request);
}

abstract class IResponseToDto<D extends BaseDto, R> {
  D? map(R response);
}

abstract class IDtoToDto<DTo extends BaseDto, DFrom extends BaseDto> {
  DTo map(DFrom dto);
}
