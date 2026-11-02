import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/place.dart';
import '../../models/place_post.dart';
import '../auth/auth_controller.dart';
import '../explore/widgets/place_visuals.dart';
import '../notifications/notifications_controller.dart';
import '../notifications/widgets/notifications_sheet.dart';
import 'feed_controller.dart';
import 'widgets/create_post_sheet.dart';
import 'widgets/post_card.dart';
import 'widgets/post_detail_screen.dart';

/// Home tab: trending places shared by the community.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenPlace,
    required this.onExplore,
    this.onOpenProfile,
  });

  final ValueChanged<Place> onOpenPlace;
  final VoidCallback onExplore;
  final VoidCallback? onOpenProfile;

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 300;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// When tapped:
  /// - If the list is scrolled down (offset > 0.0), smoothly scroll back to top.
  /// - If already at the top (offset <= 0.0), programmatically trigger the RefreshIndicator.
  void scrollToTopOrRefresh() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset > 0.0) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _refreshIndicatorKey.currentState?.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feed = ref.watch(feedProvider);
    final user = ref.watch(authProvider).user;
    final featured = feed.posts.take(3).toList(growable: false);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showScrollToTop) ...[
            FloatingActionButton.small(
              heroTag: 'home_scroll_to_top_btn',
              onPressed: scrollToTopOrRefresh,
              tooltip: 'Home (Scroll to top)',
              child: const Icon(Icons.arrow_upward_rounded),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.extended(
            heroTag: 'post_place_btn',
            onPressed: () => CreatePostSheet.show(context),
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Post place'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: () => ref.read(feedProvider.notifier).refresh(),
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
            children: [
              _Header(
                name: user?.firstName ?? 'traveler',
                initials: user?.initials ?? 'D',
                photoUrl: user?.photoUrl,
                onOpenProfile: widget.onOpenProfile,
                onPost: () => CreatePostSheet.show(context),
                onOpenPlace: widget.onOpenPlace,
              ),
              const SizedBox(height: 14),
              _SharePlacePrompt(
                photoUrl: user?.photoUrl,
                initials: user?.initials ?? 'D',
                firstName: user?.firstName ?? 'traveler',
                onTap: () => CreatePostSheet.show(context),
              ),
              const SizedBox(height: 18),
              if (feed.loading && feed.posts.isEmpty)
                const _FeedSkeleton()
              else if (feed.error != null && feed.posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: ErrorBanner(
                    message: feed.error!,
                    onRetry: () => ref.read(feedProvider.notifier).refresh(),
                  ),
                )
              else if (feed.posts.isEmpty)
                EmptyState(
                  icon: Icons.travel_explore_rounded,
                  title: 'No stories yet',
                  message:
                      'Be the first to share a place. Trending posts from other travellers will show up here.',
                  actionLabel: 'Explore places',
                  onAction: widget.onExplore,
                )
              else ...[
                if (feed.error != null) ...[
                  ErrorBanner(
                    message: feed.error!,
                    onRetry: () => ref.read(feedProvider.notifier).refresh(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (featured.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Viral right now',
                    trailing: 'Phnom Penh',
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFF97316),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 186,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _FeaturedPost(
                        post: featured[index],
                        rank: index + 1,
                        onTap: () => PostDetailScreen.show(
                          context,
                          post: featured[index],
                          onOpenPlace: widget.onOpenPlace,
                          rank: index + 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                _SectionHeader(
                  title: 'Trending posts',
                  trailing: '${feed.posts.length} stories',
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < feed.posts.length; index++)
                  PostCard(
                    post: feed.posts[index],
                    rank: index + 1,
                    onOpenPlace: widget.onOpenPlace,
                  ),
                if (feed.loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Refreshing…', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.name,
    required this.initials,
    this.photoUrl,
    this.onOpenProfile,
    this.onPost,
    this.onOpenPlace,
  });

  final String name;
  final String initials;
  final String? photoUrl;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onPost;
  final ValueChanged<Place>? onOpenPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCount = ref.watch(notificationsProvider).unreadCount;

    Widget avatarWidget = AuthorAvatar(
      name: name,
      photoUrl: photoUrl,
      size: 42,
    );

    if (onOpenProfile != null) {
      avatarWidget = InkWell(
        onTap: onOpenProfile,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: 'Go to Profile',
          child: avatarWidget,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Derleng',
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hi $name, find your next story',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (onPost != null) ...[
          IconButton.filledTonal(
            onPressed: onPost,
            icon: const Icon(Icons.add_location_alt_rounded, size: 20),
            tooltip: 'Share a place',
          ),
          const SizedBox(width: 8),
        ],
        IconButton.filledTonal(
          onPressed: () => NotificationsSheet.show(
            context,
            onOpenPlace: onOpenPlace,
          ),
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 9 ? '9+' : '$unreadCount',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        avatarWidget,
      ],
    );
  }
}

class _SharePlacePrompt extends StatelessWidget {
  const _SharePlacePrompt({
    required this.photoUrl,
    required this.initials,
    required this.firstName,
    required this.onTap,
  });

  final String? photoUrl;
  final String initials;
  final String firstName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              AuthorAvatar(
                name: firstName,
                photoUrl: photoUrl,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Share a place you love, $firstName…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.add_photo_alternate_outlined,
                color: scheme.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? trailing;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: iconColor ?? scheme.primary),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _FeaturedPost extends StatelessWidget {
  const _FeaturedPost({
    required this.post,
    required this.rank,
    required this.onTap,
  });

  final PlacePost post;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 246,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PostMedia(post: post, showPlayButton: false),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xCC000000),
                    ],
                    stops: [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 13,
                        color: Color(0xFFFB923C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '#$rank viral',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          iconForCategory(post.place.category),
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.place.category ?? 'place',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        if (post.place.rating != null) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            formatRating(post.place.rating!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget block(double height, {double? width, double radius = 14}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block(18, width: 160, radius: 8),
        const SizedBox(height: 12),
        SizedBox(
          height: 186,
          child: Row(
            children: [
              Expanded(child: block(186, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: block(186, radius: 20)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        block(18, width: 140, radius: 8),
        const SizedBox(height: 12),
        for (var index = 0; index < 2; index++) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    block(38, width: 38, radius: 19),
                    const SizedBox(width: 10),
                    Expanded(child: block(12, radius: 6)),
                  ],
                ),
                const SizedBox(height: 12),
                block(170, radius: 16),
                const SizedBox(height: 12),
                block(12, width: 220, radius: 6),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
