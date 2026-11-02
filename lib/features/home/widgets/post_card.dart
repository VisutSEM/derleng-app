import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/ui.dart';
import '../../../core/widgets/app_video_player_modal.dart';
import '../../../models/place.dart';
import '../../../models/place_post.dart';
import '../../auth/auth_controller.dart';
import '../../explore/widgets/place_visuals.dart';
import '../../favorites/favorites_controller.dart';
import '../feed_controller.dart';
import 'post_detail_screen.dart';

/// Cover image or video poster used by feed cards.
class PostMedia extends StatelessWidget {
  const PostMedia({
    super.key,
    required this.post,
    this.onPlay,
    this.showPlayButton = true,
  });

  final PlacePost post;
  final VoidCallback? onPlay;
  final bool showPlayButton;

  @override
  Widget build(BuildContext context) {
    final color = colorForCategory(post.place.category);
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.92),
            color.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          iconForCategory(post.place.category),
          size: 52,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );

    final url = post.thumbnailUrl;
    Widget image;
    if (url == null || url.isEmpty) {
      image = placeholder;
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else if (!kIsWeb && File(url).existsSync()) {
      image = Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      image = placeholder;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (post.isVideo && showPlayButton)
          Center(
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPlay,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders media inside an aspect ratio that automatically adapts to
/// vertical (portrait) vs landscape orientation.
class AdaptivePostMedia extends StatefulWidget {
  const AdaptivePostMedia({
    super.key,
    required this.post,
    this.onTap,
    this.onPlay,
    this.showPlayButton = true,
    this.badges,
    this.borderRadius = 16,
  });

  final PlacePost post;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final bool showPlayButton;
  final List<Widget>? badges;
  final double borderRadius;

  @override
  State<AdaptivePostMedia> createState() => _AdaptivePostMediaState();
}

class _AdaptivePostMediaState extends State<AdaptivePostMedia> {
  static final Map<String, double> _ratioCache = {};
  double? _resolvedRatio;
  ImageStream? _imageStream;
  ImageStreamListener? _streamListener;

  @override
  void initState() {
    super.initState();
    _checkAndResolve();
  }

  @override
  void didUpdateWidget(covariant AdaptivePostMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.thumbnailUrl != widget.post.thumbnailUrl ||
        oldWidget.post.aspectRatio != widget.post.aspectRatio) {
      _cleanUpListener();
      _checkAndResolve();
    }
  }

  @override
  void dispose() {
    _cleanUpListener();
    super.dispose();
  }

  void _cleanUpListener() {
    if (_imageStream != null && _streamListener != null) {
      _imageStream!.removeListener(_streamListener!);
    }
    _imageStream = null;
    _streamListener = null;
  }

  void _checkAndResolve() {
    if (widget.post.aspectRatio != null) {
      _resolvedRatio = widget.post.aspectRatio;
      return;
    }

    final url = widget.post.thumbnailUrl?.trim();
    if (url == null || url.isEmpty || widget.post.isVideo) {
      return;
    }

    if (_ratioCache.containsKey(url)) {
      _resolvedRatio = _ratioCache[url];
      return;
    }

    final match = RegExp(r'/(\d+)/(\d+)').firstMatch(url);
    if (match != null) {
      final w = double.tryParse(match.group(1)!);
      final h = double.tryParse(match.group(2)!);
      if (w != null && h != null && h > 0) {
        final ratio = w / h;
        _ratioCache[url] = ratio;
        _resolvedRatio = ratio;
        return;
      }
    }

    ImageProvider? provider;
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        (kIsWeb && (url.startsWith('blob:') || url.startsWith('data:')))) {
      provider = NetworkImage(url);
    } else if (!kIsWeb) {
      try {
        final file = File(url);
        if (file.existsSync()) {
          provider = FileImage(file);
        }
      } catch (_) {}
    }

    if (provider != null) {
      _imageStream = provider.resolve(const ImageConfiguration());
      _streamListener = ImageStreamListener((ImageInfo info, bool _) {
        final w = info.image.width;
        final h = info.image.height;
        if (h > 0) {
          final ratio = w / h;
          _ratioCache[url] = ratio;
          if (mounted) {
            setState(() {
              _resolvedRatio = ratio;
            });
          }
        }
      });
      _imageStream!.addListener(_streamListener!);
    }
  }

  double get effectiveAspectRatio {
    final raw = widget.post.aspectRatio ?? _resolvedRatio;
    if (raw == null) {
      return widget.post.isVertical ? (4 / 5) : (16 / 10);
    }

    // Vertical (portrait)
    if (raw < 0.95) {
      if (widget.post.isVideo) {
        // Vertical video: 9:16 or clamped 4:5
        return raw.clamp(9 / 16, 4 / 5);
      }
      // Vertical photo: standard 4:5 or 3:4 portrait
      return raw.clamp(3 / 4, 4 / 5);
    }

    // Square
    if (raw <= 1.05) {
      return 1.0;
    }

    // Landscape
    return raw.clamp(1.25, 16 / 9);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = effectiveAspectRatio;
    final isVertical = ratio < 0.95;

    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PostMedia(
                post: widget.post,
                onPlay: widget.onPlay,
                showPlayButton: widget.showPlayButton,
              ),
              if (isVertical)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.post.isVideo
                              ? Icons.stay_current_portrait_rounded
                              : Icons.crop_portrait_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.post.isVideo ? 'Reel' : 'Portrait',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.badges != null) ...widget.badges!,
            ],
          ),
        ),
      ),
    );
  }
}

/// One community post on the Home feed.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.rank,
    required this.onOpenPlace,
  });

  final PlacePost post;
  final int rank;
  final ValueChanged<Place> onOpenPlace;

  Future<void> _playVideo(BuildContext context) async {
    final url = post.videoUrl;
    if (url == null || url.trim().isEmpty) return;
    AppVideoPlayerModal.show(
      context,
      videoUrl: url,
      title: post.place.name,
      authorName: post.authorName,
    );
  }

  Future<void> _toggleSave(BuildContext context, WidgetRef ref) async {
    final favorites = ref.read(favoritesProvider);
    final saved = favorites.any((place) => place.id == post.place.id);
    await ref.read(feedProvider.notifier).toggleSave(post.place);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      saved ? 'Removed from saved places' : 'Saved ${post.place.name}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final feed = ref.watch(feedProvider);
    final favorites = ref.watch(favoritesProvider);
    final saved = favorites.any((place) => place.id == post.place.id);
    final liked = feed.isLiked(post.id);
    final categoryColor = colorForCategory(post.place.category);

    final currentUser = ref.watch(authProvider).user;
    final isMe = currentUser != null &&
        post.authorName.trim().toLowerCase() ==
            currentUser.name.trim().toLowerCase();
    final effectivePhotoUrl =
        post.authorAvatarUrl ?? (isMe ? currentUser.photoUrl : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            onTap: () => PostDetailScreen.show(
              context,
              post: post,
              onOpenPlace: onOpenPlace,
              rank: rank,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  AuthorAvatar(
                    name: post.authorName,
                    photoUrl: effectivePhotoUrl,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          formatRelativeTime(post.createdAt),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    iconForCategory(post.place.category),
                    size: 18,
                    color: categoryColor,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AdaptivePostMedia(
              post: post,
              onTap: () => PostDetailScreen.show(
                context,
                post: post,
                onOpenPlace: onOpenPlace,
                rank: rank,
              ),
              onPlay: () => _playVideo(context),
              badges: [
                Positioned(
                  left: 10,
                  top: 10,
                  child: _MediaBadge(
                    label: '#$rank Trending',
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFF97316),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _MediaBadge(
                    label: post.place.category ?? 'place',
                    icon: iconForCategory(post.place.category),
                    color: categoryColor,
                  ),
                ),
                if (post.mediaList.length > 1)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.mediaList.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: () => PostDetailScreen.show(
              context,
              post: post,
              onOpenPlace: onOpenPlace,
              rank: rank,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 2),
            child: Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => PostDetailScreen.show(
                  context,
                  post: post,
                  onOpenPlace: onOpenPlace,
                  rank: rank,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
                  child: Row(
                    children: [
                      PlaceAvatar(category: post.place.category, size: 34),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              post.place.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => PostDetailScreen.show(
                          context,
                          post: post,
                          onOpenPlace: onOpenPlace,
                          rank: rank,
                        ),
                        icon: const Icon(Icons.directions_rounded, size: 16),
                        label: const Text('Directions'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
            child: Row(
              children: [
                _ActionButton(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: formatCompactCount(feed.likeCount(post)),
                  color: liked ? const Color(0xFFE11D48) : scheme.onSurfaceVariant,
                  onTap: () =>
                      ref.read(feedProvider.notifier).toggleLike(post.id),
                ),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: formatCompactCount(post.comments),
                  color: scheme.onSurfaceVariant,
                  onTap: () => PostDetailScreen.show(
                    context,
                    post: post,
                    onOpenPlace: onOpenPlace,
                    rank: rank,
                  ),
                ),
                const Spacer(),
                _ActionButton(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: saved ? 'Saved' : 'Save',
                  color: saved ? scheme.primary : scheme.onSurfaceVariant,
                  onTap: () => _toggleSave(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar for post author: displays profile photo if available, or name initials (e.g. SC).
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 38,
  });

  final String name;
  final String? photoUrl;
  final double size;

  static String initialsFor(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts =
        clean.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final single = parts.first;
    return single.length >= 2
        ? single.substring(0, 2).toUpperCase()
        : single[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = photoUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    final initials = initialsFor(name);

    Widget? imageContent;
    if (hasPhoto) {
      if (url.startsWith('http://') ||
          url.startsWith('https://') ||
          (kIsWeb && (url.startsWith('blob:') || url.startsWith('data:')))) {
        imageContent = Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(scheme, initials),
        );
      } else if (!kIsWeb) {
        try {
          final file = File(url);
          if (file.existsSync()) {
            imageContent = Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(scheme, initials),
            );
          }
        } catch (_) {}
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: ClipOval(
        child: imageContent ?? _fallback(scheme, initials),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme, String initials) {
    return Container(
      color: scheme.primary.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
