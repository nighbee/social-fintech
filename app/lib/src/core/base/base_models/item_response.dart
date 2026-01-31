class ItemResponse<T> {
  const ItemResponse({required this.data});

  final T data;

  factory ItemResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return ItemResponse<T>(data: fromJsonT(json['data']));
  }
}
