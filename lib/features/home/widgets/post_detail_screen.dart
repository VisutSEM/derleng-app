import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/ui.dart';
import '../../../core/widgets/app_image_preview_modal.dart';
import '../../../core/widgets/app_video_player_modal.dart';
import '../../../models/app_notification.dart';
import '../../../models/place.dart';
import '../../../models/place_post.dart';
import '../../../models/travel_mode.dart';
import '../../auth/auth_controller.dart';
import '../../explore/explore_controller.dart';
import '../../explore/widgets/place_visuals.dart';
import '../../favorites/favorites_controller.dart';
import '../../notifications/notifications_controller.dart';
import '../../../data/providers.dart';
import '../feed_controller.dart';
import 'post_card.dart';

import '../../../models/post_comment.dart';
export '../../../models/post_comment.dart';

/// Comprehensive Post Detail screen with full media, place information,
/// navigation & directions actions, social interactions, and comments.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onOpenPlace,
    this.rank,
  });

  final PlacePost post;
  final ValueChanged<Place> onOpenPlace;
  final int? rank;

  static Future<void> show(
    BuildContext context, {
    required PlacePost post,
    required ValueChanged<Place> onOpenPlace,
    int? rank,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PostDetailScreen(
          post: post,
          onOpenPlace: onOpenPlace,
          rank: rank,
        ),
      ),
    );
  }

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  late final PageController _mediaCarouselController;
  int _currentMediaIndex = 0;
  late List<PostComment> _comments;
  String? _activeReactionPickerCommentId;
  TravelMode _selectedMode = TravelMode.driving;
  Timer? _replyTimer;

  @override
  void initState() {
    super.initState();
    _mediaCarouselController = PageController();
    _comments = <PostComment>[];
    _loadLiveComments();
  }

  Future<void> _loadLiveComments() async {
    try {
      final live =
          await ref.read(feedRepositoryProvider).fetchComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = List<PostComment>.from(live);
      });
    } catch (_) {
      // API error or offline
    }
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _mediaCarouselController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playVideo([String? customUrl]) async {
    final url = customUrl ?? widget.post.videoUrl;
    if (url == null || url.trim().isEmpty) return;
    AppVideoPlayerModal.show(
      context,
      videoUrl: url,
      title: widget.post.place.name,
      authorName: widget.post.authorName,
    );
  }

  void _openGallery(int initialIndex) {
    final mediaList = widget.post.mediaList;
    if (mediaList.isEmpty) return;
    AppImagePreviewModal.showGallery(
      context,
      items: mediaList,
      initialIndex: initialIndex,
      title: widget.post.place.name,
      authorName: widget.post.authorName,
      caption: widget.post.caption,
    );
  }

  void _onMediaTap(int index) {
    final mediaList = widget.post.mediaList;
    if (index < 0 || index >= mediaList.length) return;
    final item = mediaList[index];
    if (item.isVideo) {
      _playVideo(item.url);
    } else {
      _openGallery(index);
    }
  }

  Future<void> _openGoogleMaps() async {
    final lat = widget.post.place.location.lat;
    final lng = widget.post.place.location.lng;
    final name = Uri.encodeComponent(widget.post.place.name);
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name';
    try {
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showAppSnackBar(context, 'Could not launch Google Maps.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Error opening maps.', isError: true);
      }
    }
  }

  void _getDirections() {
    // Select the place and mode in exploreProvider and switch to the Explore map
    ref.read(exploreProvider.notifier).selectPlace(widget.post.place);
    widget.onOpenPlace(widget.post.place);
    Navigator.of(context).pop();
    showAppSnackBar(
      context,
      'Opening live route for "${widget.post.place.name}"…',
    );
  }

  Future<void> _toggleSave() async {
    final favorites = ref.read(favoritesProvider);
    final saved =
        favorites.any((place) => place.id == widget.post.place.id);
    await ref.read(feedProvider.notifier).toggleSave(widget.post.place);
    if (!mounted) return;
    showAppSnackBar(
      context,
      saved
          ? 'Removed "${widget.post.place.name}" from saved'
          : 'Saved "${widget.post.place.name}"',
    );
  }

  Future<void> _toggleCommentReaction(PostComment comment, String emoji) async {
    final isNewReaction = comment.userReaction != emoji;
    final updated = comment.toggleReaction(emoji);

    setState(() {
      _comments = _comments.map((c) => c.id == comment.id ? updated : c).toList();
      _activeReactionPickerCommentId = null;
    });

    try {
      await ref.read(feedRepositoryProvider).toggleCommentReaction(
            commentId: comment.id,
            reaction: emoji,
          );
    } catch (_) {
      // Best-effort local update
    }

    if (isNewReaction) {
      final user = ref.read(authProvider).user;
      final userName = user?.name ?? 'You';

      // Load reaction notification into notificationsProvider
      ref.read(notificationsProvider.notifier).addNotification(
        title: '$userName reacted with $emoji',
        message: 'Reacted to ${comment.authorName}\'s comment: "${comment.text}"',
        type: NotificationType.like,
        avatarUrl: comment.authorPhotoUrl,
        placeId: widget.post.place.id,
        postId: widget.post.id,
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Reacted with $emoji to ${comment.authorName}\'s comment',
      );
    }
  }

  void _simulateTraveler() {
    ref.read(feedProvider.notifier).addTravelerReaction(widget.post.id, '🔥');

    final travelerComment = PostComment(
      id: 'c-traveler-${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'Sokha Traveler',
      text: 'Such a breathtaking place in Cambodia! ✨',
      createdAt: DateTime.now(),
      reactions: {'❤️': 1, '🔥': 1},
    );

    setState(() {
      _comments = [travelerComment, ..._comments];
    });

    ref.read(feedProvider.notifier).incrementCommentCount(widget.post.id);

    ref.read(notificationsProvider.notifier).addNotification(
      title: 'Sokha Traveler commented on this post',
      message: '"Such a breathtaking place in Cambodia! ✨"',
      type: NotificationType.comment,
      placeId: widget.post.place.id,
      postId: widget.post.id,
    );

    showAppSnackBar(
      context,
      'Traveler reacted 🔥 and commented on this post!',
    );
  }

  void _showPostReactionPicker(BuildContext context, PlacePost post) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const emojis = ['❤️', '👍', '🔥', '👏', '😍', '🎉'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'React to ${post.place.name}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((emoji) {
                  final isSelected = post.userReaction == emoji;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(feedProvider.notifier)
                          .toggleReaction(post.id, emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary.withValues(alpha: 0.15)
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    final authorName = user?.name ?? 'Traveler';
    final photoUrl = user?.photoUrl;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    final optimisticComment = PostComment(
      id: 'comment-${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName,
      authorPhotoUrl: photoUrl,
      text: text,
      createdAt: DateTime.now(),
      isAuthor: authorName == widget.post.authorName,
    );

    setState(() {
      _comments = [optimisticComment, ..._comments];
    });

    ref.read(feedProvider.notifier).incrementCommentCount(widget.post.id);

    try {
      final realComment = await ref.read(feedRepositoryProvider).addComment(
            postId: widget.post.id,
            content: text,
          );
      if (mounted) {
        setState(() {
          final idx = _comments.indexOf(optimisticComment);
          if (idx != -1) {
            _comments[idx] = realComment;
          }
        });
      }
    } catch (_) {
      // Keep optimistic entry if API error or offline
    }

    // Load notification into notificationsProvider
    ref.read(notificationsProvider.notifier).addNotification(
      title: '$authorName commented on ${widget.post.authorName}\'s story',
      message: '"$text"',
      type: NotificationType.comment,
      avatarUrl: photoUrl,
      placeId: widget.post.place.id,
      postId: widget.post.id,
    );

    if (!mounted) return;
    showAppSnackBar(context, 'Comment posted!');
  }

  void _sharePost() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final scheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Share story',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.link_rounded),
                  ),
                  title: const Text('Copy story link'),
                  subtitle: Text('https://derleng.app/p/${widget.post.id}'),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    showAppSnackBar(context, 'Link copied to clipboard!');
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.share_rounded),
                  ),
                  title: const Text('Share to other apps…'),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    showAppSnackBar(context, 'Sharing "${widget.post.place.name}" story…');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final post = widget.post;
    final feed = ref.watch(feedProvider);
    final favorites = ref.watch(favoritesProvider);
    final isSaved = favorites.any((p) => p.id == post.place.id);
    final isLiked = feed.isLiked(post.id);
    final likeCount = feed.likeCount(post);
    final categoryColor = colorForCategory(post.place.category);

    final currentUser = ref.watch(authProvider).user;
    final isMe = currentUser != null &&
        post.authorName.trim().toLowerCase() ==
            currentUser.name.trim().toLowerCase();
    final effectiveAuthorPhoto =
        post.authorAvatarUrl ?? (isMe ? currentUser.photoUrl : null);

    // Compute distance estimate from Phnom Penh / current location
    final me = ref.watch(exploreProvider).me ?? AppConfig.defaultLocation;
    final distanceMeters = me.distanceTo(post.place.location);
    final distanceFormatted = formatDistance(distanceMeters);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconForCategory(post.place.category),
                size: 16,
                color: categoryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    post.place.category ?? 'Travel Story',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isSaved ? 'Saved' : 'Save place',
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? scheme.primary : null,
            ),
            onPressed: _toggleSave,
          ),
          IconButton(
            tooltip: 'Share story',
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePost,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          AuthorAvatar(
                            name: post.authorName,
                            photoUrl: effectiveAuthorPhoto,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        post.authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: scheme.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      formatRelativeTime(post.createdAt),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.public_rounded,
                                      size: 13,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Public',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () {
                              showAppSnackBar(
                                context,
                                'Following ${post.authorName}',
                              );
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 15),
                            label: const Text('Follow'),
                          ),
                        ],
                      ),
                    ),

                    // Post Media Carousel (Horizontal Scrollable list of images and videos)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _buildMediaCarousel(
                        context,
                        post: post,
                        categoryColor: categoryColor,
                      ),
                    ),

                    // Story Caption
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        post.caption,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // Likes, Comments & Stats Pill Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final userReaction =
                                  feed.userReaction(post.id) ?? post.userReaction;
                              final hasReacted = userReaction != null || isLiked;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onLongPress: () =>
                                        _showPostReactionPicker(context, post),
                                    child: IconButton.filledTonal(
                                      tooltip: 'Tap to like, long-press to react',
                                      style: IconButton.styleFrom(
                                        backgroundColor: hasReacted
                                            ? const Color(0xFFE11D48)
                                                .withValues(alpha: 0.12)
                                            : null,
                                      ),
                                      icon: hasReacted &&
                                              userReaction != null &&
                                              userReaction != '❤️'
                                          ? Text(
                                              userReaction,
                                              style:
                                                  const TextStyle(fontSize: 20),
                                            )
                                          : Icon(
                                              hasReacted
                                                  ? Icons.favorite_rounded
                                                  : Icons.favorite_border_rounded,
                                              color: hasReacted
                                                  ? const Color(0xFFE11D48)
                                                  : scheme.onSurfaceVariant,
                                            ),
                                      onPressed: () => ref
                                          .read(feedProvider.notifier)
                                          .toggleLike(post.id),
                                    ),
                                  ),
                                  // For new posts or posts with 0 reactions: hide count number (by default 0)
                                  if (likeCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      formatCompactCount(likeCount),
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(width: 18),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_comments.isNotEmpty ? _comments.length : post.comments}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            '${post.saves} saves',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                    const SizedBox(height: 14),

                    // =========================================================
                    // PROMINENT PLACE & "GET DIRECTIONS" CARD
                    // =========================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PlaceAvatar(
                                    category: post.place.category,
                                    size: 46,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.place.name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          post.place.address,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: Color(0xFFEAB308),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${post.place.rating ?? 4.8}',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${post.place.ratingCount ?? 120} reviews)',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '•',
                                              style: TextStyle(
                                                color: scheme.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.near_me_rounded,
                                              size: 13,
                                              color: scheme.primary,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              distanceFormatted,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: scheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Travel Mode Selector
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _TravelModePill(
                                      icon: Icons.directions_car_rounded,
                                      label: 'Driving',
                                      isSelected: _selectedMode == TravelMode.driving,
                                      onTap: () => setState(
                                          () => _selectedMode = TravelMode.driving),
                                    ),
                                    const SizedBox(width: 8),
                                    _TravelModePill(
                                      icon: Icons.directions_bike_rounded,
                                      label: 'Moto/Bike',
                                      isSelected: _selectedMode == TravelMode.bicycling,
                                      onTap: () => setState(
                                          () => _selectedMode = TravelMode.bicycling),
                                    ),
                                    const SizedBox(width: 8),
                                    _TravelModePill(
                                      icon: Icons.directions_walk_rounded,
                                      label: 'Walking',
                                      isSelected: _selectedMode == TravelMode.walking,
                                      onTap: () => setState(
                                          () => _selectedMode = TravelMode.walking),
                                    ),
                                    const SizedBox(width: 8),
                                    _TravelModePill(
                                      icon: Icons.directions_transit_rounded,
                                      label: 'Transit',
                                      isSelected: _selectedMode == TravelMode.transit,
                                      onTap: () => setState(
                                          () => _selectedMode = TravelMode.transit),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Primary GET DIRECTIONS Button
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _getDirections,
                                      icon: const Icon(
                                        Icons.directions_rounded,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'Get Directions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 13),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _openGoogleMaps,
                                      icon: const Icon(Icons.map_rounded, size: 18),
                                      label: const Text('Maps App'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // =========================================================
                    // COMMENTS SECTION
                    // =========================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Comments (${_comments.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _simulateTraveler,
                            icon: const Icon(Icons.bolt_rounded, size: 14),
                            label: const Text(
                              'Simulate traveler',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Center(
                          child: Text(
                            'No comments yet. Be the first to start the conversation!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final c = _comments[index];
                        final isAuthor =
                            c.isAuthor || c.authorName == widget.post.authorName;
                        final isPickerOpen =
                            _activeReactionPickerCommentId == c.id;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AuthorAvatar(
                              name: c.authorName,
                              photoUrl: c.authorPhotoUrl,
                              size: 34,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: scheme.outlineVariant
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  c.authorName,
                                                  style: theme
                                                      .textTheme.labelLarge
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (isAuthor) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: scheme.primary
                                                          .withValues(alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      'Author',
                                                      style: TextStyle(
                                                        color: scheme.primary,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              formatRelativeTime(c.createdAt),
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          c.text,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  // Actions & Reactions Row
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        // Active Reaction Chips
                                        ...c.reactions.entries.map((entry) {
                                          final emoji = entry.key;
                                          final count = entry.value;
                                          final isUserReacted =
                                              c.userReaction == emoji;

                                          return InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () =>
                                                _toggleCommentReaction(c, emoji),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isUserReacted
                                                    ? scheme.primary.withValues(
                                                        alpha: 0.15)
                                                    : scheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.6),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isUserReacted
                                                      ? scheme.primary
                                                          .withValues(alpha: 0.6)
                                                      : Colors.transparent,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    emoji,
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$count',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: isUserReacted
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: isUserReacted
                                                          ? scheme.primary
                                                          : scheme
                                                              .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),

                                        // React Button (reveals emoji reaction picker)
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () {
                                            setState(() {
                                              _activeReactionPickerCommentId =
                                                  isPickerOpen ? null : c.id;
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  c.userReaction != null
                                                      ? Icons.favorite_rounded
                                                      : Icons
                                                          .add_reaction_outlined,
                                                  size: 14,
                                                  color: c.userReaction != null
                                                      ? const Color(0xFFE11D48)
                                                      : scheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  c.userReaction ?? 'React',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: c.userReaction != null
                                                        ? const Color(0xFFE11D48)
                                                        : scheme
                                                            .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Reply Button
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () {
                                            _commentController.text =
                                                '@${c.authorName} ';
                                            _commentController.selection =
                                                TextSelection.fromPosition(
                                              TextPosition(
                                                  offset: _commentController
                                                      .text.length),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            child: Text(
                                              'Reply',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Floating Emoji Reaction Picker
                                  if (isPickerOpen) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surface,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.12),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final emoji in [
                                            '❤️',
                                            '👍',
                                            '🔥',
                                            '👏',
                                            '😂',
                                            '✨'
                                          ])
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: () =>
                                                  _toggleCommentReaction(
                                                      c, emoji),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: c.userReaction == emoji
                                                      ? scheme.primary
                                                          .withValues(alpha: 0.15)
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  emoji,
                                                  style: const TextStyle(
                                                      fontSize: 18),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Add Comment Box
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  AuthorAvatar(
                    name: currentUser?.name ?? 'Me',
                    photoUrl: currentUser?.photoUrl,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _submitComment,
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCarousel(
    BuildContext context, {
    required PlacePost post,
    required Color categoryColor,
  }) {
    final mediaList = post.mediaList;
    final total = mediaList.length;
    final ratio = post.aspectRatio ?? (post.isVertical ? (4 / 5) : (16 / 10));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _mediaCarouselController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: total,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentMediaIndex = idx;
                    });
                  },
                  itemBuilder: (context, idx) {
                    final item = mediaList[idx];
                    return GestureDetector(
                      onTap: () => _onMediaTap(idx),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildCarouselItemVisual(item, post),
                          if (item.isVideo)
                            Center(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _playVideo(item.url),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                // Top Left: Trending badge
                if (widget.rank != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: Color(0xFFF97316),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#${widget.rank} Trending',
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

                // Top Right: Category badge
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          iconForCategory(post.place.category),
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.place.category ?? 'place',
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

                // Bottom Left: Counter badge ("1 of 4")
                if (total > 1)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mediaList[_currentMediaIndex].isVideo
                                ? Icons.videocam_rounded
                                : Icons.photo_camera_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_currentMediaIndex + 1}/$total',
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

                // Bottom Right: Action pill (Zoom or Play)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: GestureDetector(
                    onTap: () => _onMediaTap(_currentMediaIndex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mediaList[_currentMediaIndex].isVideo
                                ? Icons.play_circle_filled_rounded
                                : Icons.zoom_in_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            mediaList[_currentMediaIndex].isVideo
                                ? 'Play'
                                : 'Zoom',
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
                ),
              ],
            ),
          ),
        ),

        // Thumbnail strip if there are multiple images/videos
        if (total > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: total,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final item = mediaList[idx];
                final isSelected = idx == _currentMediaIndex;
                final theme = Theme.of(context);

                return GestureDetector(
                  onTap: () {
                    _mediaCarouselController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 56 : 46,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                        width: isSelected ? 2.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
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
                          _buildSmallThumb(item, post),
                          if (item.isVideo)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCarouselItemVisual(PostMediaItem item, PlacePost post) {
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

    final url = item.isVideo ? (item.thumbnailUrl ?? item.url) : item.url;
    if (url.isEmpty) return placeholder;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else if (!kIsWeb && File(url).existsSync()) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }

  Widget _buildSmallThumb(PostMediaItem item, PlacePost post) {
    final url = item.isVideo ? (item.thumbnailUrl ?? item.url) : item.url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(color: Colors.grey.shade900),
      );
    } else if (!kIsWeb && File(url).existsSync()) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(color: Colors.grey.shade900),
      );
    }
    return Container(color: Colors.grey.shade900);
  }
}

class _TravelModePill extends StatelessWidget {
  const _TravelModePill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? scheme.primary
          : scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
