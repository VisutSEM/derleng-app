import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui.dart';
import '../../../models/place.dart';
import '../../auth/auth_controller.dart';
import '../../explore/widgets/place_visuals.dart';
import '../feed_controller.dart';

import 'new_post_screen.dart';

/// Modal bottom sheet allowing travellers to post and share a place.
class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({
    super.key,
    this.initialPlace,
  });

  final Place? initialPlace;

  static Future<void> show(
    BuildContext context, {
    Place? initialPlace,
  }) {
    return NewPostScreen.show(context, initialPlace: initialPlace);
  }

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _captionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  Place? _selectedPlace;
  bool _submitting = false;

  static const List<Map<String, String>> _samplePresets = [
    {
      'label': '🌅 Sunrise',
      'url': 'https://picsum.photos/seed/sunrise-derleng/900/600',
    },
    {
      'label': '🌇 Sunset',
      'url': 'https://picsum.photos/seed/sunset-quay/900/600',
    },
    {
      'label': '🏛️ Heritage',
      'url': 'https://picsum.photos/seed/heritage-temple/900/600',
    },
    {
      'label': '☕ Cafe & Bites',
      'url': 'https://picsum.photos/seed/cafe-vibes/900/600',
    },
    {
      'label': '🌃 Night City',
      'url': 'https://picsum.photos/seed/night-market-city/900/600',
    },
  ];

  @override
  void initState() {
    super.initState();
    final feedPosts = ref.read(feedProvider).posts;
    _selectedPlace = widget.initialPlace ??
        (feedPosts.isNotEmpty ? feedPosts.first.place : null);
    _imageUrlController.text = _samplePresets.first['url']!;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      showAppSnackBar(context, 'Please add a short story or caption.', isError: true);
      return;
    }
    final place = _selectedPlace;
    if (place == null) {
      showAppSnackBar(context, 'Please select a place to share.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    final user = ref.read(authProvider).user;
    final authorName = user?.name ?? 'Traveler';
    final photoUrl = user?.photoUrl;
    final imageUrl = _imageUrlController.text.trim().isEmpty
        ? 'https://picsum.photos/seed/${place.id}/900/600'
        : _imageUrlController.text.trim();

    try {
      await ref.read(feedProvider.notifier).createPost(
            authorName: authorName,
            authorAvatarUrl: photoUrl,
            caption: caption,
            place: place,
            imageUrl: imageUrl,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackBar(context, 'Story shared for ${place.name}!');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, 'Could not share post. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Post a place',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Share your experience with the Derleng community',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Selected Place',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Place>(
                      isExpanded: true,
                      value: _selectedPlace,
                      items: () {
                        final feedPlaces = ref
                            .read(feedProvider)
                            .posts
                            .map((p) => p.place)
                            .toList();
                        final seen = <String>{};
                        final list = [
                          ?_selectedPlace,
                          ...feedPlaces,
                        ].where((p) => seen.add(p.id)).toList();
                        return list.map((place) {
                          return DropdownMenuItem<Place>(
                            value: place,
                            child: Row(
                              children: [
                                PlaceAvatar(category: place.category, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      }(),
                      onChanged: (place) {
                        if (place != null) {
                          setState(() => _selectedPlace = place);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your story & tips',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _captionController,
                  maxLines: 3,
                  maxLength: 280,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What did you love here? Best time to visit, food tips, or highlights...',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Photo or Media',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _samplePresets.map((preset) {
                      final isSelected = _imageUrlController.text == preset['url'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset['label']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _imageUrlController.text = preset['url']!;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    hintText: 'Or enter custom image URL',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Sharing…' : 'Share to feed'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
