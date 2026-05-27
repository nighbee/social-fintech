import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:video_player/video_player.dart';

class MediaViewerItem {
  const MediaViewerItem({
    required this.url,
    required this.type,
    this.thumbnailUrl,
  });

  final String url;
  final String type;
  final String? thumbnailUrl;

  bool get isVideo {
    final normalized = type.trim().toLowerCase();
    return normalized == 'video' || normalized.startsWith('video/');
  }
}

Future<void> showMediaViewer(
  BuildContext context, {
  required List<MediaViewerItem> items,
  int initialIndex = 0,
}) {
  if (items.isEmpty) {
    return Future<void>.value();
  }

  final safeIndex = initialIndex.clamp(0, items.length - 1).toInt();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MediaViewerPage(
        items: items,
        initialIndex: safeIndex,
      ),
    ),
  );
}

class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MediaViewerItem> items;
  final int initialIndex;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late final PageController _pageController;
  late int _index;
  bool _downloading = false;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    if (_downloading) return;

    final item = widget.items[_index];
    final uri = Uri.tryParse(item.url.trim());
    if (uri == null) {
      _showSnack('Could not download this media.');
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = _extensionFor(uri, item);
      final name =
          'brightbund_${DateTime.now().millisecondsSinceEpoch}_$_index$ext';
      final path = '${tempDir.path}${Platform.pathSeparator}$name';

      final hasPermission = await _ensureGalleryPermission();
      if (!hasPermission) {
        _showSnack('Allow photo access to save this media.');
        return;
      }

      final SaveResult result;
      if (item.isVideo) {
        await Dio().download(
          uri.toString(),
          path,
          onReceiveProgress: (received, total) {
            if (!mounted || total <= 0) return;
            setState(() => _downloadProgress = received / total);
          },
        );

        result = await SaverGallery.saveFile(
          filePath: path,
          fileName: name,
          androidRelativePath: 'Movies/BrightBund',
          skipIfExists: false,
        );
      } else {
        final response = await Dio().get<List<int>>(
          uri.toString(),
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: (received, total) {
            if (!mounted || total <= 0) return;
            setState(() => _downloadProgress = received / total);
          },
        );

        result = await SaverGallery.saveImage(
          Uint8List.fromList(response.data ?? const <int>[]),
          fileName: name,
          androidRelativePath: 'Pictures/BrightBund',
          skipIfExists: false,
        );
      }

      if (!mounted) return;
      _showSnack(
        result.isSuccess
            ? 'Saved to gallery.'
            : (result.errorMessage ?? 'Could not save this media.'),
      );
    } catch (_) {
      if (mounted) {
        _showSnack('Could not download this media.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  String _extensionFor(Uri uri, MediaViewerItem item) {
    final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dotIndex = lastSegment.lastIndexOf('.');
    final pathExt = dotIndex == -1 ? '' : lastSegment.substring(dotIndex);
    if (pathExt.isNotEmpty && pathExt.length <= 8) {
      return pathExt;
    }
    return item.isVideo ? '.mp4' : '.jpg';
  }

  Future<bool> _ensureGalleryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.items.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                if (item.isVideo) {
                  return _FullscreenVideo(item: item);
                }
                return _FullscreenImage(url: item.url);
              },
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (hasMultiple)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '${_index + 1}/${widget.items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  _RoundIconButton(
                    icon: Icons.file_download_outlined,
                    onTap: _downloadCurrent,
                    progress: _downloading ? (_downloadProgress ?? 0) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  const _FullscreenImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            );
          },
        ),
      ),
    );
  }
}

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.item});

  final MediaViewerItem item;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() => _showControls = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ready)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else if ((widget.item.thumbnailUrl ?? '').trim().isNotEmpty)
            Center(
              child: Image.network(
                widget.item.thumbnailUrl!.trim(),
                fit: BoxFit.contain,
              ),
            )
          else
            const SizedBox.shrink(),
          if (_error != null)
            const Text(
              'Video is unavailable',
              style: TextStyle(color: Colors.white70),
            )
          else if (!ready)
            const CircularProgressIndicator(
              color: Colors.white70,
              strokeWidth: 2,
            ),
          if (ready && _showControls)
            _RoundIconButton(
              icon: controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 64,
              iconSize: 40,
              onTap: _togglePlay,
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.progress,
    this.size = 44,
    this.iconSize = 25,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double? progress;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final value = progress;
    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: Colors.white, size: iconSize),
              if (value != null)
                SizedBox(
                  width: math.max(18, size - 14),
                  height: math.max(18, size - 14),
                  child: CircularProgressIndicator(
                    value: value,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
