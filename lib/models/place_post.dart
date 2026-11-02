import 'place.dart';

/// A user post about a place, shown on the Home feed.
///
/// Returned by `GET /feed?sort=trending`:
///
/// ```json
/// {
///   "id": "post-1",
///   "author": { "name": "Sokha", "avatar_url": "https://..." },
///   "caption": "Sunrise at the Royal Palace",
///   "place": { "id": "royal-palace", "name": "Royal Palace", ... },
///   "image_url": "https://...",
///   "video_url": null,
///   "likes": 1240,
///   "comments": 38,
///   "saves": 210,
///   "trending_score": 98,
///   "created_at": "2026-10-30T08:00:00Z"
/// }
/// ```
/// The type of media attached to a post.
enum PostMediaType { image, video }

/// One media item (image or video) in a post's horizontal gallery.
class PostMediaItem {
  const PostMediaItem({
    required this.url,
    this.type = PostMediaType.image,
    this.aspectRatio,
    this.thumbnailUrl,
    this.title,
  });

  final String url;
  final PostMediaType type;
  final double? aspectRatio;
  final String? thumbnailUrl;
  final String? title;

  bool get isVideo => type == PostMediaType.video;
  bool get isImage => type == PostMediaType.image;

  factory PostMediaItem.fromJson(Map<String, dynamic> json) {
    final typeStr = '${json['type'] ?? json['media_type'] ?? ''}'.toLowerCase();
    final urlStr = '${json['url'] ?? json['image_url'] ?? json['video_url'] ?? ''}';
    final isVid = typeStr == 'video' || urlStr.toLowerCase().contains('.mp4');
    return PostMediaItem(
      url: urlStr,
      type: isVid ? PostMediaType.video : PostMediaType.image,
      aspectRatio: (json['aspect_ratio'] is num)
          ? (json['aspect_ratio'] as num).toDouble()
          : null,
      thumbnailUrl: json['thumbnail_url'] as String? ?? json['poster'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': isVideo ? 'video' : 'image',
        if (aspectRatio != null) 'aspect_ratio': aspectRatio,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        if (title != null) 'title': title,
      };
}

class PlacePost {
  const PlacePost({
    required this.id,
    required this.authorName,
    required this.caption,
    required this.place,
    required this.createdAt,
    this.authorAvatarUrl,
    this.imageUrl,
    this.videoUrl,
    this.aspectRatio,
    this.media,
    this.reactions = const {},
    this.userReaction,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.trendingScore = 0,
  });

  final String id;
  final String authorName;
  final String? authorAvatarUrl;
  final String caption;
  final Place place;
  final String? imageUrl;
  final String? videoUrl;
  final double? aspectRatio;
  final List<PostMediaItem>? media;
  final Map<String, int> reactions;
  final String? userReaction;
  final int likes;
  final int comments;
  final int saves;
  final DateTime createdAt;
  final int trendingScore;

  int get totalReactions {
    final sum = reactions.values.fold(0, (s, c) => s + c);
    return sum > 0 ? sum : likes;
  }

  bool get isVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  /// Whether this post's media is vertical (portrait).
  bool get isVertical => (aspectRatio != null && aspectRatio! < 0.95);

  /// Whether this post's media is landscape.
  bool get isLandscape => (aspectRatio != null && aspectRatio! > 1.05);

  /// Thumbnail used for the card: the poster image, or the video frame.
  String? get thumbnailUrl => imageUrl ?? videoUrl;

  /// Full horizontal list of images and videos available for this post and place.
  List<PostMediaItem> get mediaList {
    if (media != null && media!.isNotEmpty) {
      return media!;
    }
    final list = <PostMediaItem>[];
    if (isVideo) {
      if (videoUrl != null && videoUrl!.trim().isNotEmpty) {
        list.add(
          PostMediaItem(
            url: videoUrl!,
            type: PostMediaType.video,
            thumbnailUrl: imageUrl,
            aspectRatio: aspectRatio ?? (9 / 16),
            title: '${place.name} - Video Reel',
          ),
        );
      }
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
        list.add(
          PostMediaItem(
            url: imageUrl!,
            type: PostMediaType.image,
            aspectRatio: aspectRatio,
            title: '${place.name} - Photo',
          ),
        );
      }
    } else {
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
        list.add(
          PostMediaItem(
            url: imageUrl!,
            type: PostMediaType.image,
            aspectRatio: aspectRatio,
            title: '${place.name} - Photo',
          ),
        );
      }
      if (videoUrl != null && videoUrl!.trim().isNotEmpty) {
        list.add(
          PostMediaItem(
            url: videoUrl!,
            type: PostMediaType.video,
            thumbnailUrl: imageUrl,
            aspectRatio: 9 / 16,
            title: '${place.name} - Video Reel',
          ),
        );
      }
    }

    // Complementary place gallery visuals so user can scroll horizontally through multiple media
    final extra = _placeCategoryGallery(place.category, place.id);
    for (final item in extra) {
      if (!list.any((existing) => existing.url == item.url)) {
        list.add(item);
      }
    }

    return list;
  }

  PlacePost toggleReaction(String emoji) {
    final newReactions = Map<String, int>.from(reactions);
    final prevReaction = userReaction;
    String? newUserReaction;

    if (prevReaction == emoji) {
      final currentCount = newReactions[emoji] ?? 1;
      if (currentCount <= 1) {
        newReactions.remove(emoji);
      } else {
        newReactions[emoji] = currentCount - 1;
      }
      newUserReaction = null;
    } else {
      if (prevReaction != null && newReactions.containsKey(prevReaction)) {
        final oldCount = newReactions[prevReaction] ?? 1;
        if (oldCount <= 1) {
          newReactions.remove(prevReaction);
        } else {
          newReactions[prevReaction] = oldCount - 1;
        }
      }
      newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
      newUserReaction = emoji;
    }

    final sum = newReactions.values.fold(0, (s, c) => s + c);
    return copyWith(
      reactions: newReactions,
      userReaction: newUserReaction,
      clearUserReaction: newUserReaction == null,
      likes: sum,
    );
  }

  PlacePost copyWith({
    String? id,
    String? authorName,
    String? authorAvatarUrl,
    String? caption,
    Place? place,
    String? imageUrl,
    String? videoUrl,
    double? aspectRatio,
    List<PostMediaItem>? media,
    Map<String, int>? reactions,
    String? userReaction,
    bool clearUserReaction = false,
    int? likes,
    int? comments,
    int? saves,
    DateTime? createdAt,
    int? trendingScore,
  }) {
    return PlacePost(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      caption: caption ?? this.caption,
      place: place ?? this.place,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      media: media ?? this.media,
      reactions: reactions ?? Map<String, int>.from(this.reactions),
      userReaction:
          clearUserReaction ? null : (userReaction ?? this.userReaction),
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      saves: saves ?? this.saves,
      createdAt: createdAt ?? this.createdAt,
      trendingScore: trendingScore ?? this.trendingScore,
    );
  }

  factory PlacePost.fromJson(Map<String, dynamic> json) {
    final author = json['author'] ?? json['user'];
    final authorMap = author is Map ? Map<String, dynamic>.from(author) : null;

    final media = json['media'];
    List<PostMediaItem>? parsedMedia;
    if (media is List) {
      final list = <PostMediaItem>[];
      for (final m in media) {
        if (m is Map) {
          try {
            list.add(PostMediaItem.fromJson(Map<String, dynamic>.from(m)));
          } on Object {
            // Ignore malformed media item
          }
        }
      }
      if (list.isNotEmpty) parsedMedia = list;
    }
    final mediaMap = media is Map ? Map<String, dynamic>.from(media) : null;
    final mediaType = '${json['media_type'] ?? mediaMap?['type'] ?? ''}';

    final rawPlace = json['place'];
    final place = rawPlace is Map
        ? Place.fromJson(Map<String, dynamic>.from(rawPlace))
        : Place.fromJson(json);

    final mediaUrl = mediaMap?['url'];
    final rawImage = json['image_url'] ??
        json['imageUrl'] ??
        mediaMap?['poster'] ??
        (mediaType == 'video' ? null : mediaUrl);
    final rawVideo = json['video_url'] ??
        json['videoUrl'] ??
        (mediaType == 'video' ? mediaUrl : null);

    final rawAspectRatio = json['aspect_ratio'] ?? json['aspectRatio'];
    final aspectRatio =
        rawAspectRatio is num ? rawAspectRatio.toDouble() : null;

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final createdAt = rawCreatedAt is String
        ? (DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final rawLikes = json['likes'] ?? json['like_count'] ?? 0;
    final rawComments = json['comments'] ?? json['comment_count'] ?? 0;
    final rawSaves = json['saves'] ?? json['save_count'] ?? 0;
    final rawScore = json['trending_score'] ?? json['trendingScore'] ?? rawLikes;

    final rawReactions = json['reactions_summary'] ?? json['reactions'];
    final reactions = <String, int>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        if (value is num) {
          reactions['$key'] = value.toInt();
        }
      });
    }

    return PlacePost(
      id: '${json['id'] ?? 'post-${place.id}'}',
      authorName: '${authorMap?['name'] ?? json['author_name'] ?? 'Traveler'}',
      authorAvatarUrl: (authorMap?['avatar_url'] ??
          authorMap?['avatar'] ??
          json['author_avatar_url']) as String?,
      caption: '${json['caption'] ?? json['text'] ?? ''}',
      place: place,
      imageUrl: rawImage is String && rawImage.isNotEmpty ? rawImage : null,
      videoUrl: rawVideo is String && rawVideo.isNotEmpty ? rawVideo : null,
      aspectRatio: aspectRatio,
      media: parsedMedia,
      reactions: reactions,
      userReaction: json['user_reaction'] as String?,
      likes: rawLikes is num ? rawLikes.toInt() : 0,
      comments: rawComments is num ? rawComments.toInt() : 0,
      saves: rawSaves is num ? rawSaves.toInt() : 0,
      trendingScore: rawScore is num ? rawScore.toInt() : 0,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': {
          'name': authorName,
          if (authorAvatarUrl != null) 'avatar_url': authorAvatarUrl,
        },
        'caption': caption,
        'place': place.toJson(),
        if (imageUrl != null) 'image_url': imageUrl,
        if (videoUrl != null) 'video_url': videoUrl,
        if (aspectRatio != null) 'aspect_ratio': aspectRatio,
        if (media != null && media!.isNotEmpty)
          'media': media!.map((m) => m.toJson()).toList(),
        'reactions': reactions,
        if (userReaction != null) 'user_reaction': userReaction,
        'likes': likes,
        'comments': comments,
        'saves': saves,
        'trending_score': trendingScore,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) => other is PlacePost && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PlacePost($id, ${place.name})';
}

List<PostMediaItem> _placeCategoryGallery(String? category, String placeId) {
  final cat = (category ?? '').toLowerCase();
  if (cat.contains('temple') || cat.contains('heritage')) {
    return const [
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 16 / 10,
        title: 'Temple Grand Entrance',
      ),
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 4 / 5,
        title: 'Sacred Stupa & Statues',
      ),
      PostMediaItem(
        url:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
        type: PostMediaType.video,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=600&q=80',
        aspectRatio: 9 / 16,
        title: 'Temple Walkthrough Reel',
      ),
    ];
  } else if (cat.contains('cafe') || cat.contains('coffee')) {
    return const [
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 16 / 10,
        title: 'Cozy Interior Seating',
      ),
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 4 / 5,
        title: 'Artisan Brew & Pastries',
      ),
      PostMediaItem(
        url:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        type: PostMediaType.video,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=600&q=80',
        aspectRatio: 16 / 9,
        title: 'Barista Moments',
      ),
    ];
  } else if (cat.contains('market')) {
    return const [
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 16 / 10,
        title: 'Bustling Market Aisles',
      ),
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 4 / 5,
        title: 'Authentic Street Food',
      ),
      PostMediaItem(
        url:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
        type: PostMediaType.video,
        thumbnailUrl:
            'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=600&q=80',
        aspectRatio: 9 / 16,
        title: 'Night Market Walk',
      ),
    ];
  } else if (cat.contains('restaurant') || cat.contains('food')) {
    return const [
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 16 / 10,
        title: 'Chef Special Dishes',
      ),
      PostMediaItem(
        url:
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80',
        type: PostMediaType.image,
        aspectRatio: 4 / 5,
        title: 'Fresh Local Tasting Plate',
      ),
    ];
  }

  // Default landmark / destination
  return const [
    PostMediaItem(
      url:
          'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80',
      type: PostMediaType.image,
      aspectRatio: 16 / 10,
      title: 'Scenic Panorama',
    ),
    PostMediaItem(
      url:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      type: PostMediaType.image,
      aspectRatio: 4 / 5,
      title: 'Sunset Skyline View',
    ),
    PostMediaItem(
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      type: PostMediaType.video,
      thumbnailUrl:
          'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=600&q=80',
      aspectRatio: 16 / 9,
      title: 'City Lights Reel',
    ),
  ];
}
