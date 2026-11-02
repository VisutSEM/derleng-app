import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/ui.dart';
import '../../../models/app_notification.dart';
import '../../../models/place.dart';
import '../../../models/place_post.dart';
import '../../home/feed_controller.dart';
import '../../home/widgets/post_card.dart';
import '../../home/widgets/post_detail_screen.dart';
import '../notifications_controller.dart';

/// Modal bottom sheet showing community & travel notifications.
class NotificationsSheet extends ConsumerStatefulWidget {
  const NotificationsSheet({
    super.key,
    this.onOpenPlace,
  });

  final ValueChanged<Place>? onOpenPlace;

  static Future<void> show(
    BuildContext context, {
    ValueChanged<Place>? onOpenPlace,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationsSheet(onOpenPlace: onOpenPlace),
    );
  }

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  bool _filterOnlyUnread = false;

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case NotificationType.trending:
        return Icons.local_fire_department_rounded;
      case NotificationType.story:
        return Icons.video_library_rounded;
      case NotificationType.system:
        return Icons.campaign_rounded;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return const Color(0xFFF43F5E);
      case NotificationType.comment:
        return const Color(0xFF3B82F6);
      case NotificationType.trending:
        return const Color(0xFFF97316);
      case NotificationType.story:
        return const Color(0xFF8B5CF6);
      case NotificationType.system:
        return const Color(0xFF10B981);
    }
  }

  void _handleTapNotification(AppNotification notif) {
    ref.read(notificationsProvider.notifier).markAsRead(notif.id);

    // If notification is linked to a post, open post details
    if (notif.postId != null) {
      final feedPosts = ref.read(feedProvider).posts;
      PlacePost? post;
      for (final p in feedPosts) {
        if (p.id == notif.postId) {
          post = p;
          break;
        }
      }

      if (post != null) {
        Navigator.of(context).pop();
        PostDetailScreen.show(
          context,
          post: post,
          onOpenPlace: widget.onOpenPlace ?? (_) {},
        );
        return;
      }
    }

    // If notification is linked to a place, open the place
    if (notif.placeId != null && widget.onOpenPlace != null) {
      final feedPosts = ref.read(feedProvider).posts;
      for (final p in feedPosts) {
        if (p.place.id == notif.placeId) {
          Navigator.of(context).pop();
          widget.onOpenPlace!(p.place);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifState = ref.watch(notificationsProvider);
    final allItems = notifState.items;
    final items = _filterOnlyUnread
        ? allItems.where((n) => !n.isRead).toList()
        : allItems;
    final unreadCount = notifState.unreadCount;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Notifications',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: scheme.primary,
                        ),
                        onPressed: () {
                          ref
                              .read(notificationsProvider.notifier)
                              .markAllAsRead();
                          showAppSnackBar(context, 'All marked as read');
                        },
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
              ),

              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    FilterChip(
                      selected: !_filterOnlyUnread,
                      label: Text('All (${allItems.length})'),
                      onSelected: (_) => setState(() => _filterOnlyUnread = false),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _filterOnlyUnread,
                      label: Text('Unread ($unreadCount)'),
                      onSelected: (_) => setState(() => _filterOnlyUnread = true),
                    ),
                    const Spacer(),
                    if (allItems.isNotEmpty)
                      IconButton(
                        iconSize: 20,
                        color: scheme.onSurfaceVariant,
                        tooltip: 'Clear all notifications',
                        onPressed: () {
                          ref.read(notificationsProvider.notifier).clearAll();
                          showAppSnackBar(context, 'Notifications cleared');
                        },
                        icon: const Icon(Icons.clear_all_rounded),
                      ),
                  ],
                ),
              ),

              const Divider(height: 18),

              // Notifications List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _filterOnlyUnread
                                      ? Icons.done_all_rounded
                                      : Icons.notifications_none_rounded,
                                  size: 48,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filterOnlyUnread
                                    ? 'No unread notifications'
                                    : 'All caught up!',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _filterOnlyUnread
                                    ? 'You have read all your updates and travel stories.'
                                    : 'When people like your stories, comment, or places start trending, you\'ll see them here.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final notif = items[index];
                          final badgeColor = _colorForType(notif.type);
                          final badgeIcon = _iconForType(notif.type);

                          return Dismissible(
                            key: ValueKey(notif.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: scheme.error,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(notificationsProvider.notifier)
                                  .delete(notif.id);
                              showAppSnackBar(
                                context,
                                'Notification deleted',
                              );
                            },
                            child: Material(
                              color: notif.isRead
                                  ? scheme.surface
                                  : scheme.primaryContainer
                                      .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _handleTapNotification(notif),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Avatar or Type Icon
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          if (notif.avatarUrl != null)
                                            AuthorAvatar(
                                              name: notif.title,
                                              photoUrl: notif.avatarUrl,
                                              size: 44,
                                            )
                                          else
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    badgeColor.withValues(
                                                        alpha: 0.85),
                                                    badgeColor.withValues(
                                                        alpha: 0.45),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  badgeIcon,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                            ),

                                          // Mini badge on avatar
                                          if (notif.avatarUrl != null)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  color: badgeColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: theme
                                                        .scaffoldBackgroundColor,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Icon(
                                                  badgeIcon,
                                                  size: 10,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),

                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notif.title,
                                                    style: theme
                                                        .textTheme.bodyMedium
                                                        ?.copyWith(
                                                      fontWeight: notif.isRead
                                                          ? FontWeight.w600
                                                          : FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  formatRelativeTime(
                                                      notif.createdAt),
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: scheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.7),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              notif.message,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Unread indicator dot
                                      if (!notif.isRead) ...[
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: scheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
