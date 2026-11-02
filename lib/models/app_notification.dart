enum NotificationType {
  like,
  comment,
  trending,
  story,
  system,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.avatarUrl,
    this.placeId,
    this.postId,
  });

  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? avatarUrl;
  final String? placeId;
  final String? postId;

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? avatarUrl,
    String? placeId,
    String? postId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      placeId: placeId ?? this.placeId,
      postId: postId ?? this.postId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (placeId != null) 'place_id': placeId,
      if (postId != null) 'post_id': postId,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
      placeId: json['place_id'] as String?,
      postId: json['post_id'] as String?,
    );
  }
}
