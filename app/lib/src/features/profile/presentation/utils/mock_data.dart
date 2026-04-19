import 'package:app/src/features/home/domain/entities/post_entity.dart';

final List<PostEntity> mockPosts = List.generate(14, (index) {
  final hasImage = index < 9;

  return PostEntity(
    id: 'post_$index',
    userId: 'mock_user_1',
    username: 'mockuser',
    content: hasImage
        ? 'Captured another brightbund moment #$index'
        : 'Text-only update #$index. This post should appear after the media grid when you scroll lower in the profile.',
    imageUrls:
        hasImage ? ['https://picsum.photos/400/400?random=$index'] : const [],
    createdAt: DateTime.now().subtract(Duration(days: index)),
    likesCount: (index * 10) + 5,
    commentsCount: index * 2,
  );
});
