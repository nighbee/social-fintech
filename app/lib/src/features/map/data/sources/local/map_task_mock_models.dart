class MapTaskMockHelper {
  const MapTaskMockHelper({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class MapActiveTaskMock {
  const MapActiveTaskMock({
    required this.taskId,
    required this.title,
    required this.code,
    required this.description,
    required this.heroesCount,
    required this.reward,
    required this.createdAt,
  });

  final String taskId;
  final String title;
  final String code;
  final String description;
  final int heroesCount;
  final int reward;
  final DateTime createdAt;
}
