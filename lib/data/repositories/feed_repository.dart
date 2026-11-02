import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../models/place.dart';
import '../../models/place_post.dart';
import '../../models/post_comment.dart';
import '../demo/demo_data.dart';

/// Trending community posts shown on the Home tab.
abstract class FeedRepository {
  /// Returns the most viral posts first.
  Future<List<PlacePost>> trending({int limit = 20});

  /// Shares a user post about a place.
  Future<PlacePost> createPost({
    required String authorName,
    String? authorAvatarUrl,
    required String caption,
    required Place place,
    String? imageUrl,
    String? videoUrl,
    double? aspectRatio,
    List<PostMediaItem>? media,
  });

  /// Updates an existing post.
  Future<PlacePost> updatePost(PlacePost post);

  /// Deletes a post by id.
  Future<void> deletePost(String postId);

  /// Retrieves comments for a specific post.
  Future<List<PostComment>> fetchComments(String postId);

  /// Posts a new comment to a post.
  Future<PostComment> addComment({
    required String postId,
    required String content,
  });

  /// Reacts or toggles a reaction on a comment.
  Future<Map<String, dynamic>> toggleCommentReaction({
    required String commentId,
    required String reaction,
  });
}

/// Talks to the Laravel proxy: `GET /feed?sort=trending&limit=20`.
class ApiFeedRepository implements FeedRepository {
  ApiFeedRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<PlacePost>> trending({int limit = 20}) async {
    final data = await _client.get(
      '/feed',
      query: {'sort': 'trending', 'limit': limit},
    );
    final raw = data is Map ? data['data'] : data;
    if (raw is! List) return const [];

    final posts = <PlacePost>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        posts.add(PlacePost.fromJson(Map<String, dynamic>.from(item)));
      } on Object {
        // Skip malformed posts instead of failing the whole feed.
      }
    }
    return posts;
  }

  @override
  Future<PlacePost> createPost({
    required String authorName,
    String? authorAvatarUrl,
    required String caption,
    required Place place,
    String? imageUrl,
    String? videoUrl,
    double? aspectRatio,
    List<PostMediaItem>? media,
  }) async {
    final authorMap = <String, dynamic>{'name': authorName};
    if (authorAvatarUrl != null) {
      authorMap['avatar_url'] = authorAvatarUrl;
    }
    final payload = <String, dynamic>{
      'author': authorMap,
      'caption': caption,
      'place': place.toJson(),
    };
    if (imageUrl != null) {
      payload['image_url'] = imageUrl;
    }
    if (videoUrl != null) {
      payload['video_url'] = videoUrl;
    }
    if (aspectRatio != null) {
      payload['aspect_ratio'] = aspectRatio;
    }
    if (media != null && media.isNotEmpty) {
      payload['media'] = media.map((m) => m.toJson()).toList();
    }
    final res = await _client.post('/feed/posts', data: payload);
    final map = res is Map ? (res['data'] is Map ? res['data'] : res) : res;
    return PlacePost.fromJson(Map<String, dynamic>.from(map as Map));
  }

  @override
  Future<PlacePost> updatePost(PlacePost post) async {
    final res = await _client.put(
      '/feed/posts/${post.id}',
      data: post.toJson(),
    );
    final map = res is Map ? (res['data'] is Map ? res['data'] : res) : res;
    return PlacePost.fromJson(Map<String, dynamic>.from(map as Map));
  }

  @override
  Future<void> deletePost(String postId) async {
    await _client.delete('/feed/posts/$postId');
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async {
    try {
      final res = await _client.get('/feed/posts/$postId/comments');
      final raw = res is Map ? res['data'] : res;
      if (raw is! List) return const [];

      final comments = <PostComment>[];
      for (final item in raw) {
        if (item is Map) {
          try {
            comments.add(PostComment.fromJson(Map<String, dynamic>.from(item)));
          } on Object {
            // skip malformed comment
          }
        }
      }
      return comments;
    } on Object {
      return const [];
    }
  }

  @override
  Future<PostComment> addComment({
    required String postId,
    required String content,
  }) async {
    final res = await _client.post(
      '/feed/posts/$postId/comments',
      data: {'content': content.trim()},
    );
    final map = res is Map ? (res['data'] is Map ? res['data'] : res) : res;
    return PostComment.fromJson(Map<String, dynamic>.from(map as Map));
  }

  @override
  Future<Map<String, dynamic>> toggleCommentReaction({
    required String commentId,
    required String reaction,
  }) async {
    final res = await _client.post(
      '/feed/comments/$commentId/reaction',
      data: {'reaction': reaction.trim()},
    );
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }
}

/// Serves the bundled sample feed while the backend is unavailable.
class DemoFeedRepository implements FeedRepository {
  DemoFeedRepository({this.latency = AppConfig.demoLatency});

  final Duration latency;
  final Map<String, List<PostComment>> _demoComments = {};

  @override
  Future<List<PlacePost>> trending({int limit = 20}) async {
    await Future<void>.delayed(latency);
    return DemoData.trendingPosts(limit: limit);
  }

  @override
  Future<PlacePost> createPost({
    required String authorName,
    String? authorAvatarUrl,
    required String caption,
    required Place place,
    String? imageUrl,
    String? videoUrl,
    double? aspectRatio,
    List<PostMediaItem>? media,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final newPost = PlacePost(
      id: 'post-${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      caption: caption,
      place: place,
      imageUrl: imageUrl ??
          'https://picsum.photos/seed/${place.id}-${DateTime.now().millisecondsSinceEpoch % 1000}/900/600',
      videoUrl: videoUrl,
      aspectRatio: aspectRatio,
      media: media,
      likes: 1,
      comments: 0,
      saves: 0,
      trendingScore: 99,
      createdAt: DateTime.now(),
    );
    DemoData.posts.insert(0, newPost);
    return newPost;
  }

  @override
  Future<PlacePost> updatePost(PlacePost post) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final index = DemoData.posts.indexWhere((p) => p.id == post.id);
    if (index != -1) {
      DemoData.posts[index] = post;
    }
    return post;
  }

  @override
  Future<void> deletePost(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    DemoData.posts.removeWhere((p) => p.id == postId);
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return _demoComments[postId] ?? const [];
  }

  @override
  Future<PostComment> addComment({
    required String postId,
    required String content,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final comment = PostComment(
      id: 'comment-${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'Traveler',
      text: content,
      createdAt: DateTime.now(),
    );
    final list = _demoComments[postId] ?? [];
    list.insert(0, comment);
    _demoComments[postId] = list;
    return comment;
  }

  @override
  Future<Map<String, dynamic>> toggleCommentReaction({
    required String commentId,
    required String reaction,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return {'reacted': true, 'reaction': reaction};
  }
}

