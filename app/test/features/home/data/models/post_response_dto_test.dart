import 'package:app/src/features/home/data/models/post_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a text-only feed post with null media attachments', () {
    final dto = PostResponseDto.fromJson(<String, dynamic>{
      'post_id': '485c6c7f-b92e-4427-8d3b-dfbb0c212bb3',
      'author': <String, dynamic>{
        'id': '7c94b742-33e1-45dd-aa1b-f477f5d4dbd1',
        'username': 'user',
        'full_name': 'Test User',
        'profile_pic_url': '',
        'rank': 'Pearl | Awareness | C',
        'reputation_score': 0,
      },
      'time_ago': '5d',
      'visibility': 'ANYONE',
      'comment_permission': 'ANYONE',
      'content_text': 'Text-only post',
      'media_attachments': null,
      'metrics': <String, dynamic>{
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'silvers': 0,
      },
      'permissions': <String, dynamic>{'can_comment': true},
      'hide_likes_count': false,
      'is_own_post': false,
      'viewer_has_liked': false,
    });

    expect(dto.mediaAttachments, isEmpty);
    expect(dto.contentText, 'Text-only post');
    expect(dto.permissions.canComment, isTrue);
  });
}
