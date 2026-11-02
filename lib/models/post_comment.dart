/// A comment on a community post with interactive reactions.
class PostComment {
  const PostComment({
    required this.id,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorPhotoUrl,
    this.isAuthor = false,
    this.reactions = const {},
    this.userReaction,
  });

  final String id;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;
  final bool isAuthor;
  final Map<String, int> reactions;
  final String? userReaction;

  int get totalReactions =>
      reactions.values.fold(0, (sum, count) => sum + count);

  PostComment copyWith({
    String? id,
    String? authorName,
    String? authorPhotoUrl,
    String? text,
    DateTime? createdAt,
    bool? isAuthor,
    Map<String, int>? reactions,
    String? userReaction,
    bool clearUserReaction = false,
  }) {
    return PostComment(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isAuthor: isAuthor ?? this.isAuthor,
      reactions: reactions ?? Map<String, int>.from(this.reactions),
      userReaction:
          clearUserReaction ? null : (userReaction ?? this.userReaction),
    );
  }

  PostComment toggleReaction(String emoji) {
    final newReactions = Map<String, int>.from(reactions);
    final prevReaction = userReaction;
    String? newUserReaction;

    if (prevReaction == emoji) {
      // User tapped the same emoji -> remove it
      final currentCount = newReactions[emoji] ?? 1;
      if (currentCount <= 1) {
        newReactions.remove(emoji);
      } else {
        newReactions[emoji] = currentCount - 1;
      }
      newUserReaction = null;
    } else {
      // If user previously reacted with another emoji, decrement it
      if (prevReaction != null && newReactions.containsKey(prevReaction)) {
        final oldCount = newReactions[prevReaction] ?? 1;
        if (oldCount <= 1) {
          newReactions.remove(prevReaction);
        } else {
          newReactions[prevReaction] = oldCount - 1;
        }
      }
      // Increment the selected emoji
      newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
      newUserReaction = emoji;
    }

    return copyWith(
      reactions: newReactions,
      userReaction: newUserReaction,
      clearUserReaction: newUserReaction == null,
    );
  }

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final authorMap = author is Map ? Map<String, dynamic>.from(author) : null;
    final rawReactions = json['reactions_summary'] ?? json['reactions'];
    final reactions = <String, int>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        if (value is num) {
          reactions['$key'] = value.toInt();
        }
      });
    }

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final createdAt = rawCreatedAt is String
        ? (DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    return PostComment(
      id: '${json['id'] ?? ''}',
      authorName: '${authorMap?['name'] ?? json['author_name'] ?? 'Traveler'}',
      authorPhotoUrl: (authorMap?['avatar_url'] ??
          authorMap?['avatar'] ??
          json['author_avatar_url']) as String?,
      text: '${json['content'] ?? json['text'] ?? ''}',
      createdAt: createdAt,
      reactions: reactions,
      userReaction: json['user_reaction'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': {
          'name': authorName,
          if (authorPhotoUrl != null) 'avatar_url': authorPhotoUrl,
        },
        'content': text,
        'reactions_summary': reactions,
        if (userReaction != null) 'user_reaction': userReaction,
        'created_at': createdAt.toIso8601String(),
      };
}
