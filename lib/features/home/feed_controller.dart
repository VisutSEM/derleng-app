import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/providers.dart';
import '../../models/place.dart';
import '../../models/place_post.dart';
import '../favorites/favorites_controller.dart';

class FeedState {
  const FeedState({
    this.posts = const [],
    this.loading = true,
    this.error,
    this.liked = const {},
  });

  final List<PlacePost> posts;
  final bool loading;
  final String? error;

  /// Likes are optimistic and local until the backend exposes `POST /likes`.
  final Set<String> liked;

  bool isLiked(String postId) {
    if (liked.contains(postId)) return true;
    final match = posts.where((p) => p.id == postId).firstOrNull;
    return match?.userReaction != null;
  }

  String? userReaction(String postId) {
    final match = posts.where((p) => p.id == postId).firstOrNull;
    return match?.userReaction ?? (liked.contains(postId) ? '❤️' : null);
  }

  int likeCount(PlacePost post) {
    final livePost = posts.where((p) => p.id == post.id).firstOrNull ?? post;
    if (livePost.reactions.isNotEmpty) {
      return livePost.reactions.values.fold(0, (sum, count) => sum + count);
    }
    if (livePost.userReaction != null) {
      return livePost.likes > 0 ? livePost.likes : 1;
    }
    return livePost.likes + (liked.contains(post.id) ? 1 : 0);
  }

  static const Object _unset = Object();

  FeedState copyWith({
    List<PlacePost>? posts,
    bool? loading,
    Object? error = _unset,
    Set<String>? liked,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
      liked: liked ?? this.liked,
    );
  }
}

class FeedController extends Notifier<FeedState> {
  @override
  FeedState build() {
    Future<void>.microtask(refresh);
    return const FeedState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final posts = await ref.read(feedRepositoryProvider).trending();
      if (!ref.mounted) return;
      state = state.copyWith(posts: posts, loading: false, error: null);
    } on ApiException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.message);
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: 'Could not load the feed. Pull down to try again.',
      );
    }
  }

  void addPost(PlacePost post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  void toggleReaction(String postId, String emoji) {
    var found = false;
    final updatedList = state.posts.map((post) {
      if (post.id == postId) {
        found = true;
        return post.toggleReaction(emoji);
      }
      return post;
    }).toList();

    if (!found) return;

    final liked = {...state.liked};
    final match = updatedList.firstWhere((p) => p.id == postId);
    if (match.userReaction != null) {
      liked.add(postId);
    } else {
      liked.remove(postId);
    }

    state = state.copyWith(posts: updatedList, liked: liked);

    ref.read(feedRepositoryProvider).togglePostReaction(
          postId: postId,
          reaction: emoji,
        );
  }

  void toggleLike(String postId) {
    final current = state.userReaction(postId);
    toggleReaction(postId, current ?? '❤️');
  }

  /// Adds a reaction from another user/traveler to simulate social activity.
  void addTravelerReaction(String postId, [String emoji = '🔥']) {
    final updatedList = state.posts.map((post) {
      if (post.id == postId) {
        final newReactions = Map<String, int>.from(post.reactions);
        newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
        final sum = newReactions.values.fold(0, (s, c) => s + c);
        return post.copyWith(
          reactions: newReactions,
          likes: sum,
        );
      }
      return post;
    }).toList();
    state = state.copyWith(posts: updatedList);
  }

  Future<void> toggleSave(Place place) =>
      ref.read(favoritesProvider.notifier).toggle(place);

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
    final post = await ref.read(feedRepositoryProvider).createPost(
          authorName: authorName,
          authorAvatarUrl: authorAvatarUrl,
          caption: caption,
          place: place,
          imageUrl: imageUrl,
          videoUrl: videoUrl,
          aspectRatio: aspectRatio,
          media: media,
        );
    final cleanLiked = {...state.liked}..remove(post.id);
    state = state.copyWith(
      posts: [post, ...state.posts],
      liked: cleanLiked,
    );
    return post;
  }

  Future<PlacePost> updatePost(PlacePost updated) async {
    final result = await ref.read(feedRepositoryProvider).updatePost(updated);
    final updatedList = state.posts
        .map((post) => post.id == result.id ? result : post)
        .toList();
    state = state.copyWith(posts: updatedList);
    return result;
  }

  Future<void> deletePost(String postId) async {
    await ref.read(feedRepositoryProvider).deletePost(postId);
    final updatedList = state.posts.where((post) => post.id != postId).toList();
    final liked = {...state.liked}..remove(postId);
    state = state.copyWith(posts: updatedList, liked: liked);
  }

  void incrementCommentCount(String postId) {
    final updatedList = state.posts.map((post) {
      if (post.id == postId) {
        return post.copyWith(comments: post.comments + 1);
      }
      return post;
    }).toList();
    state = state.copyWith(posts: updatedList);
  }
}

final feedProvider = NotifierProvider<FeedController, FeedState>(
  FeedController.new,
);
