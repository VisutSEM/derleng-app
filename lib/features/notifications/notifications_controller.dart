import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/app_notification.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_controller.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
  });

  final List<AppNotification> items;

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
  }) {
    return NotificationsState(
      items: items ?? this.items,
    );
  }
}

class NotificationsController extends Notifier<NotificationsState> {
  static final List<AppNotification> _defaultDemoNotifications = [
    AppNotification(
      id: 'notif-demo-1',
      title: 'Piseth Seng liked your story',
      message: 'Liked your post about Royal Palace',
      type: NotificationType.like,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      isRead: false,
    ),
    AppNotification(
      id: 'notif-demo-2',
      title: 'Bopha Chen commented on your post',
      message: '"Stunning angle! Which camera did you use?"',
      type: NotificationType.comment,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    AppNotification(
      id: 'notif-demo-3',
      title: 'Trending near you',
      message: 'Angkor Wat is receiving high visitor attention this morning.',
      type: NotificationType.trending,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
  ];

  @override
  NotificationsState build() {
    ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    if (!settings.demoMode) {
      Future.microtask(fetchLiveNotifications);
      return const NotificationsState(items: []);
    }
    return NotificationsState(items: List.of(_defaultDemoNotifications));
  }

  Future<void> fetchLiveNotifications() async {
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/notifications');
      final raw = res is Map ? res['data'] : res;
      if (raw is! List) return;

      final items = <AppNotification>[];
      for (final item in raw) {
        if (item is Map) {
          try {
            items.add(AppNotification.fromJson(Map<String, dynamic>.from(item)));
          } on Object {
            // skip malformed
          }
        }
      }
      state = state.copyWith(items: items);
    } catch (_) {
      // Keep current state on error
    }
  }

  Future<void> markAsRead(String id) async {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id == id) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList(),
    );

    try {
      await ref.read(apiClientProvider).put('/notifications/$id/read');
    } catch (_) {
      // best-effort
    }
  }

  Future<void> markAllAsRead() async {
    state = state.copyWith(
      items: state.items.map((item) => item.copyWith(isRead: true)).toList(),
    );

    try {
      await ref.read(apiClientProvider).put('/notifications/read-all');
    } catch (_) {
      // best-effort
    }
  }

  Future<void> delete(String id) async {
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
    );

    try {
      await ref.read(apiClientProvider).delete('/notifications/$id');
    } catch (_) {
      // best-effort
    }
  }

  void clearAll() {
    state = state.copyWith(items: const []);
  }

  void addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    String? avatarUrl,
    String? placeId,
    String? postId,
  }) {
    final newNotif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      avatarUrl: avatarUrl,
      placeId: placeId,
      postId: postId,
    );
    state = state.copyWith(items: [newNotif, ...state.items]);
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);

