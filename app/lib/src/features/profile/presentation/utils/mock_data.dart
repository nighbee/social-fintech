import 'package:app/src/features/profile/presentation/models/profile_post_item.dart';

final List<ProfilePostItem> mockPosts = List.generate(
  15,
  (index) => ProfilePostItem(
    id: 'post_$index',
    imageUrls: ['https://picsum.photos/400/400?random=$index'],
  ),
);
