import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:flutter/material.dart';

class ProfilePostGrid extends StatelessWidget {
  /// Figma cell proportion (width × height).
  static const double _cellAspectRatio = 132 / 120;
  static const BorderRadius _cellBorderRadius = BorderRadius.all(
    Radius.circular(2),
  );

  const ProfilePostGrid({
    required this.posts,
    this.onPostTap,
    super.key,
  });

  final List<PostEntity> posts;

  /// Opens full publications list; [PostEntity.id] is used as anchor when non-null.
  final ValueChanged<String>? onPostTap;

  @override
  Widget build(BuildContext context) {
    final mediaPosts = posts
        .where((post) => post.imageUrls.isNotEmpty)
        .toList(growable: false);

    if (mediaPosts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Assets.icons.images.svg(
                width: 120,
                height: 120,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFCACACA),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: TextStyles.titleMain.copyWith(
                  color: const Color(0xFFCACACA),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: _cellAspectRatio,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final post = mediaPosts[index];
            final child = CustomNetworkImage(
              imageUrl: post.imageUrls.first,
              fit: BoxFit.cover,
              borderRadius: _cellBorderRadius,
            );
            final onTap = onPostTap;
            if (onTap == null) {
              return child;
            }
            return Material(
              color: Colors.transparent,
              borderRadius: _cellBorderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(post.id),
                borderRadius: _cellBorderRadius,
                child: child,
              ),
            );
          }, childCount: mediaPosts.length),
        ),
      ],
    );
  }
}
