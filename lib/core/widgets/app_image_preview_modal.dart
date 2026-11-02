import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/place_post.dart';
import '../utils/ui.dart';
import 'app_video_player_modal.dart';

/// Full-screen horizontal media gallery and zoom preview modal.
///
/// Supports horizontal swiping between multiple images and videos,
/// interactive pinch-to-zoom and double-tap zoom for images,
/// instant video playback, and a horizontal thumbnail strip.
class AppImagePreviewModal extends StatefulWidget {
  const AppImagePreviewModal({
    super.key,
    this.imageUrl,
    this.items,
    this.initialIndex = 0,
    this.title,
    this.authorName,
    this.caption,
    this.heroTag,
  });

  final String? imageUrl;
  final List<PostMediaItem>? items;
  final int initialIndex;
  final String? title;
  final String? authorName;
  final String? caption;
  final String? heroTag;

  /// Convenience single-image launcher (backwards-compatible).
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? authorName,
    String? caption,
    String? heroTag,
  }) {
    if (imageUrl.trim().isEmpty) {
      showAppSnackBar(context, 'No image available to preview.', isError: true);
      return Future.value();
    }

    return showGallery(
      context,
      items: [
        PostMediaItem(
          url: imageUrl,
          type: PostMediaType.image,
          title: title,
        ),
      ],
      initialIndex: 0,
      title: title,
      authorName: authorName,
      caption: caption,
      heroTag: heroTag,
    );
  }

  /// Convenience multi-media horizontal gallery launcher.
  static Future<void> showGallery(
    BuildContext context, {
    required List<PostMediaItem> items,
    int initialIndex = 0,
    String? title,
    String? authorName,
    String? caption,
    String? heroTag,
  }) {
    if (items.isEmpty) {
      showAppSnackBar(context, 'No media available to preview.', isError: true);
      return Future.value();
    }

    final safeIndex = initialIndex.clamp(0, items.length - 1);

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close media gallery',
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return AppImagePreviewModal(
          items: items,
          initialIndex: safeIndex,
          title: title,
          authorName: authorName,
          caption: caption,
          heroTag: heroTag,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AppImagePreviewModal> createState() => _AppImagePreviewModalState();
}

class _AppImagePreviewModalState extends State<AppImagePreviewModal>
    with SingleTickerProviderStateMixin {
  late final List<PostMediaItem> _items;
  late final PageController _pageController;
  late int _currentIndex;

  late final TransformationController _transformationController;
  late final AnimationController _animController;
  late final CurvedAnimation _curvedAnimation;
  Matrix4 _startMatrix = Matrix4.identity();
  Matrix4 _targetMatrix = Matrix4.identity();

  Offset? _doubleTapPosition;
  double _currentScale = 1.0;
  bool _showOverlays = true;
  bool _showCaption = false;

  PostMediaItem get _currentItem =>
      _items.isNotEmpty ? _items[_currentIndex] : const PostMediaItem(url: '');

  @override
  void initState() {
    super.initState();
    if (widget.items != null && widget.items!.isNotEmpty) {
      _items = widget.items!;
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _items = [
        PostMediaItem(
          url: widget.imageUrl!,
          type: PostMediaType.image,
          title: widget.title,
        ),
      ];
    } else {
      _items = [];
    }

    _currentIndex = widget.initialIndex.clamp(0, _items.isEmpty ? 0 : _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _curvedAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    )..addListener(() {
        final t = _curvedAnimation.value;
        final current =
            Matrix4Tween(begin: _startMatrix, end: _targetMatrix).transform(t);
        _transformationController.value = current;
        final scale = current.getMaxScaleOnAxis();
        if ((scale - _currentScale).abs() > 0.02) {
          setState(() {
            _currentScale = scale;
          });
        }
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _curvedAnimation.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.02) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _animateToMatrix(Matrix4 target) {
    _startMatrix = _transformationController.value;
    _targetMatrix = target;
    _animController.forward(from: 0);
  }

  void _animateToScale(double targetScale, {Offset? focalPoint}) {
    final current = _transformationController.value;
    final currentScale = current.getMaxScaleOnAxis();
    if (currentScale == 0) return;

    if (targetScale <= 1.05) {
      _resetZoom();
      return;
    }

    final size = MediaQuery.sizeOf(context);
    final center = focalPoint ?? Offset(size.width / 2, size.height / 2);

    final factor = targetScale / currentScale;
    final matrix = Matrix4.copy(current)
      ..translateByDouble(center.dx, center.dy, 0.0, 1.0)
      ..scaleByDouble(factor, factor, 1.0, 1.0)
      ..translateByDouble(-center.dx, -center.dy, 0.0, 1.0);

    _animateToMatrix(matrix);
  }

  void _resetZoom() {
    _animateToMatrix(Matrix4.identity());
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final target = (currentScale * 1.45).clamp(1.0, 5.0);
    _animateToScale(target);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale <= 1.1) {
      _resetZoom();
      return;
    }
    final target = (currentScale / 1.45).clamp(1.0, 5.0);
    if (target <= 1.1) {
      _resetZoom();
    } else {
      _animateToScale(target);
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _onDoubleTap() {
    if (_currentItem.isVideo) return;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.25) {
      _resetZoom();
    } else {
      _animateToScale(2.5, focalPoint: _doubleTapPosition);
    }
  }

  void _toggleOverlays() {
    setState(() {
      _showOverlays = !_showOverlays;
    });
  }

  void _onPageChanged(int index) {
    _resetZoom();
    setState(() {
      _currentIndex = index;
    });
  }

  void _playVideo(String videoUrl) {
    AppVideoPlayerModal.show(
      context,
      videoUrl: videoUrl,
      title: _currentItem.title ?? widget.title,
      authorName: widget.authorName,
    );
  }

  bool _isNetworkUrl(String url) =>
      url.startsWith('http://') ||
      url.startsWith('https://') ||
      (kIsWeb && (url.startsWith('blob:') || url.startsWith('data:')));

  bool _isLocalFilePath(String url) =>
      !kIsWeb && !_isNetworkUrl(url) && File(url).existsSync();

  Widget _buildImageWidget(String url) {
    if (_isNetworkUrl(url)) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final total = progress.expectedTotalBytes;
          final loaded = progress.cumulativeBytesLoaded;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    value: total != null && total > 0 ? loaded / total : null,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Loading high-res photo…',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
        errorBuilder: (_, _, _) => _buildErrorFallback(),
      );
    } else if (_isLocalFilePath(url)) {
      return Image.file(
        File(url),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _buildErrorFallback(),
      );
    }
    return _buildErrorFallback();
  }

  Widget _buildVideoCard(PostMediaItem item) {
    final posterUrl = item.thumbnailUrl ?? item.url;
    return Center(
      child: AspectRatio(
        aspectRatio: item.aspectRatio ?? (16 / 9),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video thumbnail background
                if (posterUrl.isNotEmpty && !_isNetworkUrl(item.url))
                  _buildImageWidget(posterUrl)
                else if (item.thumbnailUrl != null &&
                    item.thumbnailUrl!.isNotEmpty)
                  Image.network(
                    item.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0F172A),
                          const Color(0xFF1E293B),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        size: 64,
                        color: Colors.white38,
                      ),
                    ),
                  ),

                // Dark gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),

                // Center Play Button
                Center(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _playVideo(item.url),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom video reel label
                Positioned(
                  left: 16,
                  bottom: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_filled_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Video Reel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (item.title != null)
                        Expanded(
                          child: Text(
                            item.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.broken_image_rounded,
                size: 42,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load media',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The media link or file could not be displayed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageItem(int index) {
    if (index < 0 || index >= _items.length) {
      return _buildErrorFallback();
    }
    final item = _items[index];

    if (item.isVideo) {
      return _buildVideoCard(item);
    }

    final isCurrent = index == _currentIndex;

    Widget imageContent = Center(
      child: _buildImageWidget(item.url),
    );

    if (widget.heroTag != null && index == widget.initialIndex) {
      imageContent = Hero(tag: widget.heroTag!, child: imageContent);
    }

    // Only attach interactive controller to the active page
    if (isCurrent) {
      return GestureDetector(
        onTap: _toggleOverlays,
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: _onDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          clipBehavior: Clip.none,
          child: imageContent,
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleOverlays,
      child: imageContent,
    );
  }

  Widget _buildThumbnailStrip() {
    if (_items.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isSelected = i == _currentIndex;

              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 58 : 46,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : Colors.white.withValues(alpha: 0.3),
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.isVideo)
                          Container(
                            color: const Color(0xFF1E293B),
                            child: item.thumbnailUrl != null
                                ? Image.network(
                                    item.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.videocam_rounded,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.videocam_rounded,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                  ),
                          )
                        else if (_isNetworkUrl(item.url))
                          Image.network(
                            item.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade900,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 16,
                                color: Colors.white54,
                              ),
                            ),
                          )
                        else if (_isLocalFilePath(item.url))
                          Image.file(
                            File(item.url),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade900,
                            ),
                          )
                        else
                          Container(color: Colors.grey.shade900),

                        // Video play badge on thumbnail
                        if (item.isVideo)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scalePercent = (_currentScale * 100).round();
    final isZoomed = _currentScale > 1.05;
    final isVideo = _currentItem.isVideo;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background dismiss area
          GestureDetector(
            onTap: _toggleOverlays,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),

          // Horizontal scrollable PageView of media
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            // Disable page swipe while zoomed in so user can pan around photo freely
            physics: isZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: _items.length,
            itemBuilder: (context, index) => _buildPageItem(index),
          ),

          // Top App Bar Overlay
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _showOverlays ? 0 : -110,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Close button
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 22),
                        tooltip: 'Close preview',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentItem.title ??
                                  widget.title ??
                                  'Media Gallery',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.authorName != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    isVideo
                                        ? Icons.videocam_outlined
                                        : Icons.camera_alt_outlined,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${isVideo ? 'Video' : 'Photo'} by ${widget.authorName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Counter pill ("1 of 4")
                      if (_items.length > 1)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentIndex + 1} of ${_items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // Zoom percentage pill button (for images)
                      if (!isVideo)
                        Material(
                          color: isZoomed
                              ? const Color(0xFF2563EB)
                              : Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: isZoomed ? _resetZoom : _zoomIn,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isZoomed
                                        ? Icons.fit_screen_rounded
                                        : Icons.search_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$scalePercent%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Caption card overlay (if toggled)
          if (widget.caption != null &&
              widget.caption!.trim().isNotEmpty &&
              _showCaption)
            Positioned(
              left: 16,
              right: 16,
              bottom: _items.length > 1 ? 160 : 100,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  widget.caption!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),

          // Bottom Floating Controls Toolbar & Thumbnails
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _showOverlays ? 0 : -140,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.92),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Horizontal thumbnail list
                    _buildThumbnailStrip(),

                    // Control toolbar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E)
                                  .withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isVideo) ...[
                                  // Play Video Button
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFE11D48),
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _playVideo(_currentItem.url),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Play Video',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  // Zoom Out (-)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.zoom_out_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Zoom out',
                                    onPressed: _zoomOut,
                                  ),
                                  // Divider
                                  Container(
                                    height: 20,
                                    width: 1,
                                    color: Colors.white24,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  // Reset / 1:1 button
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    onPressed: _resetZoom,
                                    icon: Icon(
                                      isZoomed
                                          ? Icons.restart_alt_rounded
                                          : Icons.fit_screen_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isZoomed ? 'Reset' : '1:1',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  // Divider
                                  Container(
                                    height: 20,
                                    width: 1,
                                    color: Colors.white24,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  // Zoom In (+)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.zoom_in_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Zoom in',
                                    onPressed: _zoomIn,
                                  ),
                                ],
                                if (widget.caption != null &&
                                    widget.caption!.trim().isNotEmpty) ...[
                                  Container(
                                    height: 20,
                                    width: 1,
                                    color: Colors.white24,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  // Caption toggle
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      _showCaption
                                          ? Icons.subtitles_rounded
                                          : Icons.subtitles_outlined,
                                      color: _showCaption
                                          ? const Color(0xFF60A5FA)
                                          : Colors.white,
                                      size: 20,
                                    ),
                                    tooltip: _showCaption
                                        ? 'Hide caption'
                                        : 'Show caption',
                                    onPressed: () {
                                      setState(() {
                                        _showCaption = !_showCaption;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
