import 'package:app/src/features/home/domain/entities/post_entity.dart';

final List<PostEntity> mockPosts = List.generate(
  15,
  (index) => PostEntity(
    id: 'post_$index',
    userId: 'mock_user_1',
    username: 'mockuser',
    content: 'This is a mock post content $index',
    imageUrls: ['https://picsum.photos/400/400?random=$index'],
    createdAt: DateTime.now().subtract(Duration(days: index)),
    likesCount: (index * 10) + 5,
    commentsCount: index * 2,
  ),
);
