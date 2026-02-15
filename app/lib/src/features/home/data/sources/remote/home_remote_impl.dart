import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/post_dto.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';

@named
@LazySingleton(as: IHomeRemote)
class HomeRemoteImpl implements IHomeRemote {
  HomeRemoteImpl(@Named.from(DioClient) this._restClient);

  final RestClient _restClient;

  @override
  Future<Either<DomainException, List<PostDto>>> getPosts() async {
    // TODO: Uncomment when API is ready
    // try {
    //   final response = await _restClient.get(EndPoints.posts);
    //
    //   return response.fold((error) => Left(error), (result) {
    //     final dto = ListResponse<PostDto>.fromJson(
    //       result.data,
    //       (json) => PostDto.fromJson(json as Map<String, dynamic>),
    //     );
    //     return Right(dto.data);
    //   });
    // } catch (e) {
    //   return Left(UnknownException(message: e.toString()));
    // }

    // Mock data for development
    await Future.delayed(const Duration(milliseconds: 500));
    final mockPosts = [
      PostDto(
        id: 'post-1',
        userId: 'user-1',
        username: 'Ayaulym Yesmoldayeva',
        userAvatar: 'https://i.pravatar.cc/150?img=1',
        content: 'A good music and a good book makes life truly... see more',
        imageUrls: [
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400',
          'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=400',
          'https://images.unsplash.com/photo-1495446815901-a7297e633e8d?w=400',
        ],
        likesCount: 29,
        commentsCount: 44,
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 3))
            .toIso8601String(),
      ),
      PostDto(
        id: 'post-2',
        userId: 'user-2',
        username: 'John Bookworm',
        userAvatar: 'https://i.pravatar.cc/150?img=12',
        content: 'Just finished "The Great Gatsby". What a masterpiece! 📚✨',
        imageUrls: [
          'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400',
        ],
        likesCount: 87,
        commentsCount: 23,
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 5))
            .toIso8601String(),
      ),
      PostDto(
        id: 'post-3',
        userId: 'user-3',
        username: 'Sarah Reader',
        userAvatar: 'https://i.pravatar.cc/150?img=5',
        content:
            'My cozy reading corner is finally complete! Perfect spot for weekend reading sessions.',
        imageUrls: [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
        ],
        likesCount: 156,
        commentsCount: 67,
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 8))
            .toIso8601String(),
      ),
      PostDto(
        id: 'post-4',
        userId: 'user-4',
        username: 'Mike Literature',
        userAvatar: 'https://i.pravatar.cc/150?img=8',
        content: 'Currently reading 5 books at once. Is that normal? 😅',
        imageUrls: [],
        likesCount: 42,
        commentsCount: 18,
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 12))
            .toIso8601String(),
      ),
    ];
    return Right(mockPosts);
  }
}
