abstract class BaseRequest {
  const BaseRequest();

  /// Возвращает JSON без null значений
  // Map<String, dynamic> toJsonWithoutNulls(Map<String, dynamic> json) {
  //   json.removeWhere((key, value) => value == null);
  //   return json;
  // }
}
