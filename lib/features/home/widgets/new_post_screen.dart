import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/ui.dart';
import '../../../core/widgets/app_video_player_modal.dart';
import '../../../data/providers.dart';
import '../../../models/geo_point.dart';
import '../../../models/place.dart';
import '../../../models/place_post.dart';
import '../../auth/auth_controller.dart';
import '../../explore/widgets/place_visuals.dart';
import '../feed_controller.dart';
import 'map_pin_picker.dart';
import 'post_card.dart';

/// One selected media item (photo or video) ready to be attached to a post.
class SelectedMediaItem {
  SelectedMediaItem({
    required this.path,
    required this.name,
    required this.isVideo,
    this.aspectRatio,
  });

  final String path;
  final String name;
  final bool isVideo;
  double? aspectRatio;

  bool get isNetwork =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      (kIsWeb && (path.startsWith('blob:') || path.startsWith('data:')));
}

/// Full-screen social "New post" interface adapting to the app's default theme.
class NewPostScreen extends ConsumerStatefulWidget {
  const NewPostScreen({
    super.key,
    this.initialPlace,
  });

  final Place? initialPlace;

  static Future<void> show(
    BuildContext context, {
    Place? initialPlace,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => NewPostScreen(initialPlace: initialPlace),
      ),
    );
  }

  @override
  ConsumerState<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends ConsumerState<NewPostScreen> {
  final _captionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Place? _selectedPlace;
  String? _selectedFeeling;
  String _privacy = 'Friends';
  bool _submitting = false;

  // Selected media state: multiple photos & videos
  final List<SelectedMediaItem> _selectedMedia = [];
  int _activeMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    final feedPosts = ref.read(feedProvider).posts;
    _selectedPlace = widget.initialPlace ??
        (feedPosts.isNotEmpty ? feedPosts.first.place : null);
    _selectedMedia.clear();
    if (_selectedPlace != null && feedPosts.isNotEmpty) {
      final matchingPost = feedPosts.firstWhere(
        (p) => p.place.id == _selectedPlace!.id,
        orElse: () => feedPosts.first,
      );
      final mediaUrl = matchingPost.imageUrl ?? matchingPost.thumbnailUrl;
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        _selectedMedia.add(
          SelectedMediaItem(
            path: mediaUrl,
            name: '${_selectedPlace!.name} Photo',
            isVideo: false,
            aspectRatio: 4 / 5,
          ),
        );
      }
    }
    _activeMediaIndex = 0;
    _imageUrlController.text = '';
  }

  @override
  void dispose() {
    _captionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _detectAspectRatioForItem(SelectedMediaItem item) {
    if (item.isVideo) return;
    try {
      ImageProvider provider;
      final path = item.path;
      if (item.isNetwork) {
        provider = NetworkImage(path);
      } else if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          provider = FileImage(file);
        } else {
          return;
        }
      } else {
        return;
      }

      final stream = provider.resolve(const ImageConfiguration());
      stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
        final w = info.image.width;
        final h = info.image.height;
        if (h > 0 && mounted) {
          setState(() {
            item.aspectRatio = w / h;
          });
        }
      }));
    } catch (_) {}
  }

  void _addPickedFiles(List<({String path, String name, bool isVideo})> items) {
    if (items.isEmpty) return;
    setState(() {
      for (final it in items) {
        if (_selectedMedia.any((m) => m.path == it.path)) continue;
        final item = SelectedMediaItem(
          path: it.path,
          name: it.name,
          isVideo: it.isVideo,
          aspectRatio: it.isVideo ? (9 / 16) : null,
        );
        _selectedMedia.add(item);
        if (!it.isVideo) {
          _detectAspectRatioForItem(item);
        }
      }
      if (_selectedMedia.isNotEmpty &&
          _activeMediaIndex >= _selectedMedia.length) {
        _activeMediaIndex = _selectedMedia.length - 1;
      }
    });
  }

  Future<void> _pickMultipleImagesFromGallery() async {
    try {
      final List<XFile> files = await _imagePicker.pickMultiImage(
        imageQuality: 88,
      );
      if (files.isNotEmpty) {
        _addPickedFiles(
          files.map((f) => (path: f.path, name: f.name, isVideo: false)).toList(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      try {
        final files = await FilePickerPlatform.instance.pickFiles(
          type: FileType.image,
        );
        if (files.isNotEmpty) {
          _addPickedFiles(
            files
                .where((f) => f.path != null)
                .map((f) => (path: f.path!, name: f.name, isVideo: false))
                .toList(),
          );
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      final msg = e.toString().contains('MissingPluginException')
          ? 'New plugin added: please stop and re-run your app (flutter run) in terminal.'
          : 'Could not access photo gallery: $e';
      showAppSnackBar(context, msg, isError: true);
    }
  }

  Future<void> _pickMultipleVideosFromGallery() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.video,
      );
      if (files.isNotEmpty) {
        _addPickedFiles(
          files
              .where((f) => f.path != null)
              .map((f) => (path: f.path!, name: f.name, isVideo: true))
              .toList(),
        );
        return;
      }
    } catch (_) {}

    try {
      final file = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (file != null) {
        _addPickedFiles([(path: file.path, name: file.name, isVideo: true)]);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('MissingPluginException')
          ? 'New plugin added: please stop and re-run your app (flutter run) in terminal.'
          : 'Could not access video gallery: $e';
      showAppSnackBar(context, msg, isError: true);
    }
  }

  Future<void> _pickMixedMedia() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.media,
      );
      if (files.isNotEmpty) {
        final items = <({String path, String name, bool isVideo})>[];
        for (final file in files) {
          if (file.path == null) continue;
          final ext = (file.extension ?? '').toLowerCase();
          final isVideo =
              ['mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm'].contains(ext);
          items.add((path: file.path!, name: file.name, isVideo: isVideo));
        }
        _addPickedFiles(items);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not open media files.', isError: true);
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.camera);
      if (file != null) {
        _addPickedFiles([(path: file.path, name: file.name, isVideo: false)]);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not capture photo: $e', isError: true);
      }
    }
  }

  Future<void> _recordCameraVideo() async {
    try {
      final file = await _imagePicker.pickVideo(source: ImageSource.camera);
      if (file != null) {
        _addPickedFiles([(path: file.path, name: file.name, isVideo: true)]);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not record video: $e', isError: true);
      }
    }
  }

  void _addUrlMedia(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final isVid = trimmed.endsWith('.mp4') || trimmed.contains('video');
    final name = trimmed.split('/').last;
    final item = SelectedMediaItem(
      path: trimmed,
      name: name.isNotEmpty ? name : (isVid ? 'Web Video' : 'Web Photo'),
      isVideo: isVid,
      aspectRatio: isVid ? (16 / 9) : null,
    );
    setState(() {
      _selectedMedia.add(item);
      _activeMediaIndex = _selectedMedia.length - 1;
    });
    if (!isVid) {
      _detectAspectRatioForItem(item);
    }
  }

  static const List<Map<String, dynamic>> _tagCategories = [
    {
      'id': 'cafe',
      'label': 'Coffee / Cafe',
      'icon': Icons.local_cafe_rounded,
      'color': Color(0xFF92400E),
    },
    {
      'id': 'temple',
      'label': 'Temple / Pagoda',
      'icon': Icons.temple_buddhist_rounded,
      'color': Color(0xFFB45309),
    },
    {
      'id': 'restaurant',
      'label': 'Restaurant / Food',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFEA580C),
    },
    {
      'id': 'landmark',
      'label': 'Landmark / Monument',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF0F766E),
    },
    {
      'id': 'market',
      'label': 'Market / Street Fair',
      'icon': Icons.storefront_rounded,
      'color': Color(0xFFDB2777),
    },
    {
      'id': 'park',
      'label': 'Park / Nature',
      'icon': Icons.park_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'id': 'hotel',
      'label': 'Hotel / Resort',
      'icon': Icons.hotel_rounded,
      'color': Color(0xFF0891B2),
    },
    {
      'id': 'museum',
      'label': 'Museum / Art',
      'icon': Icons.museum_rounded,
      'color': Color(0xFF7C3AED),
    },
    {
      'id': 'mall',
      'label': 'Mall / Shopping',
      'icon': Icons.local_mall_rounded,
      'color': Color(0xFF2563EB),
    },
    {
      'id': 'place',
      'label': 'Other place',
      'icon': Icons.place_rounded,
      'color': Color(0xFF64748B),
    },
  ];

  String _categoryName(String? categoryId) {
    final found = _tagCategories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {'label': 'Place'},
    );
    return found['label'] as String;
  }

  void _showPlacePicker() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String searchQuery = '';
    List<Place>? apiSearchResults;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final query = searchQuery.trim().toLowerCase();
            final feedPosts = ref.read(feedProvider).posts;

            final List<Place> allPlaces;
            if (apiSearchResults != null) {
              allPlaces = apiSearchResults!;
            } else {
              final seen = <String>{};
              final combined = <Place>[
                ...feedPosts.map((p) => p.place),
              ];
              allPlaces = combined.where((p) => seen.add(p.id)).toList();
            }

            final filtered = (query.isEmpty || apiSearchResults != null)
                ? allPlaces
                : allPlaces.where((p) {
                    final haystack =
                        '${p.name} ${p.address} ${p.category ?? ''}'
                            .toLowerCase();
                    return haystack.contains(query);
                  }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place_rounded,
                              color: scheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Tag a place',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showAddNewPlaceSheet(context);
                        },
                        icon:
                            const Icon(Icons.add_location_alt_rounded, size: 16),
                        label: const Text('Add new'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search TextField
                  TextField(
                    onChanged: (val) async {
                      setPickerState(() => searchQuery = val);
                      final trimmed = val.trim();
                      if (trimmed.isNotEmpty) {
                        try {
                          final results = await ref
                              .read(placesRepositoryProvider)
                              .search(trimmed);
                          setPickerState(() => apiSearchResults = results);
                        } catch (_) {}
                      } else if (trimmed.isEmpty) {
                        setPickerState(() => apiSearchResults = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search or type new place name…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setPickerState(() {
                                  searchQuery = '';
                                  apiSearchResults = null;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                  const SizedBox(height: 10),
                  // Quick Actions Row: "Drop pin on Map" & "Add new tag place"
                  Row(
                    children: [
                      // 1. Drop Pin on Map (Interactive Map)
                      Expanded(
                        child: Material(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              final picked =
                                  await MapLocationPickerScreen.pickLocation(
                                context,
                                initialTitle: searchQuery.trim().isNotEmpty
                                    ? searchQuery.trim()
                                    : null,
                              );
                              if (picked != null) {
                                setState(() => _selectedPlace = picked);
                                if (mounted) {
                                  showAppSnackBar(
                                    this.context,
                                    'Tagged "${picked.name}" via Map Pin',
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.pin_drop_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Drop pin on map',
                                          style: TextStyle(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Pick exact area',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 2. Custom Place Form
                      Expanded(
                        child: Material(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _showAddNewPlaceSheet(
                                context,
                                initialName: searchQuery,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_location_alt_rounded,
                                      color: scheme.primary,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          searchQuery.isNotEmpty
                                              ? 'Add "$searchQuery"'
                                              : 'Add new tag place',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: scheme.onSurface,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Fill details form',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Places list
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 40,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'No existing places found for "$searchQuery"'
                                        : 'No places found',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () async {
                                          Navigator.of(sheetContext).pop();
                                          final picked =
                                              await MapLocationPickerScreen
                                                  .pickLocation(
                                            context,
                                            initialTitle: searchQuery
                                                    .trim()
                                                    .isNotEmpty
                                                ? searchQuery.trim()
                                                : null,
                                          );
                                          if (picked != null) {
                                            setState(() =>
                                                _selectedPlace = picked);
                                            if (mounted) {
                                              showAppSnackBar(
                                                this.context,
                                                'Tagged "${picked.name}" via Map Pin',
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                            Icons.pin_drop_rounded,
                                            size: 18),
                                        label: const Text('Drop Pin on Map'),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: () {
                                          Navigator.of(sheetContext).pop();
                                          _showAddNewPlaceSheet(
                                            context,
                                            initialName: searchQuery,
                                          );
                                        },
                                        icon: const Icon(Icons.add_rounded,
                                            size: 18),
                                        label: Text(searchQuery.isNotEmpty
                                            ? 'Create "$searchQuery"'
                                            : 'Add Custom Place'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => Divider(
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.3),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final place = filtered[index];
                              final isSelected =
                                  place.id == _selectedPlace?.id;
                              return ListTile(
                                leading: PlaceAvatar(
                                  category: place.category,
                                  size: 36,
                                ),
                                title: Text(
                                  place.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  place.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        color: scheme.primary,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() => _selectedPlace = place);
                                  Navigator.of(sheetContext).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddNewPlaceSheet(
    BuildContext context, {
    String? initialName,
    GeoPoint? initialLocation,
    String? initialAddress,
    String? initialCategory,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleController = TextEditingController(text: initialName ?? '');
    final addressController = TextEditingController(text: initialAddress ?? '');
    String selectedCategory = initialCategory ?? 'cafe';
    GeoPoint? customLocation = initialLocation;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                'Add new tag place',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Name your place, drop pin on map & pick category',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Place title field
                    Text(
                      'Place title *',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Brown Coffee Roastery, Bayon Temple…',
                        prefixIcon: const Icon(Icons.title_rounded),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Category Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category *',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _categoryName(selectedCategory),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Wrap of Category Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tagCategories.map((cat) {
                        final id = cat['id'] as String;
                        final label = cat['label'] as String;
                        final icon = cat['icon'] as IconData;
                        final color = cat['color'] as Color;
                        final isSelected = selectedCategory == id;

                        return ChoiceChip(
                          avatar: Icon(
                            icon,
                            size: 16,
                            color: isSelected ? Colors.white : color,
                          ),
                          label: Text(label),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : scheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          backgroundColor: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          side: BorderSide(
                            color: isSelected
                                ? color
                                : scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() => selectedCategory = id);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    // Drop Pin via Map Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Location on Map',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            final picked =
                                await MapLocationPickerScreen.pickLocation(
                              context,
                              initialLocation: customLocation,
                              initialTitle: titleController.text.trim(),
                              initialAddress: addressController.text.trim(),
                              initialCategory: selectedCategory,
                            );
                            if (picked != null) {
                              setSheetState(() {
                                customLocation = picked.location;
                                if (titleController.text.trim().isEmpty &&
                                    picked.name.isNotEmpty) {
                                  titleController.text = picked.name;
                                }
                                if (picked.address.isNotEmpty) {
                                  addressController.text = picked.address;
                                }
                                selectedCategory =
                                    picked.category ?? selectedCategory;
                              });
                            }
                          },
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: Text(customLocation != null
                              ? 'Change Pin'
                              : 'Drop Pin'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: customLocation != null
                          ? scheme.primary.withValues(alpha: 0.08)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final picked =
                              await MapLocationPickerScreen.pickLocation(
                            context,
                            initialLocation: customLocation,
                            initialTitle: titleController.text.trim(),
                            initialAddress: addressController.text.trim(),
                            initialCategory: selectedCategory,
                          );
                          if (picked != null) {
                            setSheetState(() {
                              customLocation = picked.location;
                              if (titleController.text.trim().isEmpty &&
                                  picked.name.isNotEmpty) {
                                titleController.text = picked.name;
                              }
                              if (picked.address.isNotEmpty) {
                                addressController.text = picked.address;
                              }
                              selectedCategory =
                                  picked.category ?? selectedCategory;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: customLocation != null
                                  ? scheme.primary.withValues(alpha: 0.35)
                                  : scheme.outlineVariant
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: customLocation != null
                                      ? scheme.primary.withValues(alpha: 0.16)
                                      : scheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  customLocation != null
                                      ? Icons.pin_drop_rounded
                                      : Icons.add_location_alt_rounded,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customLocation != null
                                          ? 'Pin Dropped: ${customLocation!.lat.toStringAsFixed(4)}, ${customLocation!.lng.toStringAsFixed(4)}'
                                          : 'Drop Pin via Map',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: customLocation != null
                                            ? scheme.primary
                                            : scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      customLocation != null
                                          ? 'Tap to adjust pin or view Satellite'
                                          : 'Pinpoint exact location, area & street visually',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: customLocation != null
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.15)
                                      : scheme.primary
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      customLocation != null
                                          ? Icons.check_circle_rounded
                                          : Icons.place_rounded,
                                      size: 13,
                                      color: customLocation != null
                                          ? const Color(0xFF10B981)
                                          : scheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      customLocation != null
                                          ? 'Pinned'
                                          : 'Open Map',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: customLocation != null
                                            ? const Color(0xFF10B981)
                                            : scheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Address / Area (optional)
                    Text(
                      'Address or Area (optional)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. BKK1, Daun Penh, Siem Reap…',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.pin_drop_rounded),
                          tooltip: 'Drop Pin on Map',
                          onPressed: () async {
                            final picked =
                                await MapLocationPickerScreen.pickLocation(
                              context,
                              initialLocation: customLocation,
                              initialTitle: titleController.text.trim(),
                              initialAddress: addressController.text.trim(),
                              initialCategory: selectedCategory,
                            );
                            if (picked != null) {
                              setSheetState(() {
                                customLocation = picked.location;
                                if (titleController.text.trim().isEmpty &&
                                    picked.name.isNotEmpty) {
                                  titleController.text = picked.name;
                                }
                                if (picked.address.isNotEmpty) {
                                  addressController.text = picked.address;
                                }
                                selectedCategory =
                                    picked.category ?? selectedCategory;
                              });
                            }
                          },
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Save & Tag Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            showAppSnackBar(
                              context,
                              'Please enter a place title.',
                              isError: true,
                            );
                            return;
                          }
                          final addr = addressController.text.trim();
                          final loc = customLocation ??
                              const GeoPoint(11.5564, 104.9282);
                          final newPlace = Place(
                            id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                            name: title,
                            address: addr.isNotEmpty
                                ? addr
                                : '${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}',
                            location: loc,
                            category: selectedCategory,
                            rating: 5.0,
                            ratingCount: 1,
                          );

                          setState(() {
                            _selectedPlace = newPlace;
                          });

                          Navigator.of(sheetContext).pop();
                          showAppSnackBar(
                            context,
                            'Tagged "$title" (${_categoryName(selectedCategory)})',
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Save & Tag Place',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMediaPicker() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Add Media',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Source Selection Options Row
                    Row(
                      children: [
                        Expanded(
                          child: _MediaSourceTile(
                            icon: Icons.photo_library_rounded,
                            label: 'Multi Photos',
                            subtitle: 'Select multiple photos',
                            color: scheme.primary,
                            onTap: () {
                              Navigator.of(context).pop();
                              _pickMultipleImagesFromGallery();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MediaSourceTile(
                            icon: Icons.video_collection_rounded,
                            label: 'Multi Videos',
                            subtitle: 'Select multiple videos',
                            color: const Color(0xFFF43F5E),
                            onTap: () {
                              Navigator.of(context).pop();
                              _pickMultipleVideosFromGallery();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MediaSourceTile(
                            icon: Icons.perm_media_rounded,
                            label: 'Photos & Videos',
                            subtitle: 'Mixed media files',
                            color: const Color(0xFF10B981),
                            onTap: () {
                              Navigator.of(context).pop();
                              _pickMixedMedia();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MediaSourceTile(
                            icon: Icons.camera_alt_rounded,
                            label: 'Take Photo',
                            subtitle: 'Camera snap',
                            color: const Color(0xFFF59E0B),
                            onTap: () {
                              Navigator.of(context).pop();
                              _pickFromCamera();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MediaSourceTile(
                            icon: Icons.videocam_rounded,
                            label: 'Record Video',
                            subtitle: 'Camera video',
                            color: const Color(0xFF8B5CF6),
                            onTap: () {
                              Navigator.of(context).pop();
                              _recordCameraVideo();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Or enter URL:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _imageUrlController,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'https://... (image or video)',
                              filled: true,
                              fillColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final text = _imageUrlController.text.trim();
                            if (text.isNotEmpty) {
                              _addUrlMedia(text);
                              _imageUrlController.clear();
                              Navigator.of(context).pop();
                            }
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFeelingPicker() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final feelings = [
      {'emoji': '😊', 'label': 'Happy'},
      {'emoji': '🎒', 'label': 'Traveling'},
      {'emoji': '✨', 'label': 'Exploring'},
      {'emoji': '☕', 'label': 'Chilling'},
      {'emoji': '📸', 'label': 'Snapping'},
      {'emoji': '🍜', 'label': 'Eating'},
      {'emoji': '🤩', 'label': 'Amazed'},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How are you feeling?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: feelings.map((f) {
                    final label = '${f['emoji']} ${f['label']}';
                    final isSelected = _selectedFeeling == label;
                    return ActionChip(
                      backgroundColor: isSelected
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      label: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        setState(() => _selectedFeeling = label);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final caption = _captionController.text.trim();
    final place = _selectedPlace;
    if (place == null) {
      showAppSnackBar(context, 'Please select a place.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    final user = ref.read(authProvider).user;
    final authorName = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : 'Sem Visut';
    final photoUrl = user?.photoUrl;

    try {
      final mediaItems = _selectedMedia.map((item) {
        return PostMediaItem(
          url: item.path,
          type: item.isVideo ? PostMediaType.video : PostMediaType.image,
          aspectRatio: item.aspectRatio,
          thumbnailUrl: item.isVideo ? null : item.path,
          title: '${place.name} - ${item.isVideo ? 'Video Reel' : 'Photo'}',
        );
      }).toList();

      final firstImage = _selectedMedia
          .where((m) => !m.isVideo)
          .map((m) => m.path)
          .firstOrNull;
      final firstVideo = _selectedMedia
          .where((m) => m.isVideo)
          .map((m) => m.path)
          .firstOrNull;

      final primaryAspectRatio = _selectedMedia.isNotEmpty
          ? _selectedMedia[_activeMediaIndex].aspectRatio
          : null;

      await ref.read(feedProvider.notifier).createPost(
            authorName: authorName,
            authorAvatarUrl: photoUrl,
            caption: caption.isEmpty ? 'Checked in at ${place.name}!' : caption,
            place: place,
            imageUrl: firstImage ??
                (_selectedMedia.isNotEmpty && !_selectedMedia.first.isVideo
                    ? _selectedMedia.first.path
                    : null),
            videoUrl: firstVideo ??
                (_selectedMedia.isNotEmpty && _selectedMedia.first.isVideo
                    ? _selectedMedia.first.path
                    : null),
            aspectRatio: primaryAspectRatio,
            media: mediaItems.isNotEmpty ? mediaItems : null,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      final countText = mediaItems.isNotEmpty
          ? ' with ${mediaItems.length} media'
          : '';
      showAppSnackBar(context, 'Story posted for ${place.name}$countText!');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, 'Could not post story. Try again.', isError: true);
    }
  }

  Widget _buildSingleMediaContent(ThemeData theme, SelectedMediaItem item) {
    final scheme = theme.colorScheme;

    if (item.isVideo) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black87,
              scheme.surfaceContainerHighest.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () {
                AppVideoPlayerModal.show(
                  context,
                  videoUrl: item.path,
                  title: _selectedPlace?.name ?? 'Selected place',
                  authorName: 'Video Preview',
                );
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFFF43F5E),
                    size: 68,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final path = item.path;
    if (item.isNetwork) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(scheme),
      );
    }

    if (!kIsWeb && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(scheme),
      );
    }

    return _placeholder(scheme);
  }

  Widget _thumbnailPlaceholder(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.photo_size_select_actual_outlined,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMediaThumbnailTile(
    int index,
    SelectedMediaItem item,
    ColorScheme scheme,
  ) {
    final isSelected = index == _activeMediaIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeMediaIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media Preview
              if (item.isVideo)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else if (item.isNetwork)
                Image.network(
                  item.path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _thumbnailPlaceholder(scheme),
                )
              else if (!kIsWeb && File(item.path).existsSync())
                Image.file(
                  File(item.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _thumbnailPlaceholder(scheme),
                )
              else
                _thumbnailPlaceholder(scheme),

              // Top-Left: Number badge
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary
                        : Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom-Left: Video Badge if video
              if (item.isVideo)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),

              // Top-Right: Quick Delete Cross Button
              Positioned(
                top: 3,
                right: 3,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMedia.removeAt(index);
                      if (_activeMediaIndex >= _selectedMedia.length) {
                        _activeMediaIndex =
                            (_selectedMedia.length - 1).clamp(0, 9999);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMoreThumbnailTile(ColorScheme scheme) {
    return GestureDetector(
      onTap: _showMediaPicker,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.5),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                color: scheme.primary,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                'Add',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          size: 48,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authProvider).user;
    final userName = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : 'Sem Visut';

    final hasMedia = _selectedMedia.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: scheme.onSurface, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New post',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurface, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // User Profile Row
                      Row(
                        children: [
                          AuthorAvatar(
                            name: userName,
                            photoUrl: user?.photoUrl,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              userName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Horizontal Action Chips Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _TopPillChip(
                              icon: Icons.people_rounded,
                              label: 'People',
                              onTap: () {},
                            ),
                            const SizedBox(width: 8),
                            _TopPillChip(
                              icon: _selectedPlace != null
                                  ? iconForCategory(_selectedPlace!.category)
                                  : Icons.location_on_rounded,
                              label: _selectedPlace != null
                                  ? _selectedPlace!.name
                                  : 'Location',
                              highlighted: _selectedPlace != null,
                              onTap: _showPlacePicker,
                            ),
                            const SizedBox(width: 8),
                            _TopPillChip(
                              icon: Icons.sentiment_satisfied_alt_rounded,
                              label: _selectedFeeling ?? 'Feeling/activity',
                              highlighted: _selectedFeeling != null,
                              onTap: _showFeelingPicker,
                            ),
                            const SizedBox(width: 8),
                            _TopPillChip(
                              icon: Icons.calendar_today_rounded,
                              label: 'Event',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Text Input Area
                      TextField(
                        controller: _captionController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                        cursorColor: scheme.primary,
                        decoration: InputDecoration(
                          hintText: "Your placed ...",
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 18,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Media Card Container
                      if (hasMedia)
                        Builder(
                          builder: (context) {
                            final activeItem =
                                _selectedMedia[_activeMediaIndex];
                            final isVertical = (activeItem.aspectRatio != null &&
                                activeItem.aspectRatio! < 0.95);
                            final previewRatio = activeItem.aspectRatio != null
                                ? (isVertical
                                    ? activeItem.aspectRatio!.clamp(0.68, 0.85)
                                    : activeItem.aspectRatio!.clamp(1.25, 1.78))
                                : (isVertical ? (4 / 5) : (16 / 10));

                            final photoCount =
                                _selectedMedia.where((m) => !m.isVideo).length;
                            final videoCount =
                                _selectedMedia.where((m) => m.isVideo).length;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Media count badge & action bar
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.collections_rounded,
                                            size: 14,
                                            color: scheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${_selectedMedia.length} Media ($photoCount photo${photoCount == 1 ? '' : 's'}${videoCount > 0 ? ', $videoCount video${videoCount == 1 ? '' : 's'}' : ''})',
                                            style: TextStyle(
                                              color: scheme.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: _showMediaPicker,
                                      icon: const Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Add more'),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Clear all',
                                      icon: Icon(
                                        Icons.delete_sweep_outlined,
                                        color: scheme.error,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedMedia.clear();
                                          _activeMediaIndex = 0;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Main Hero Media Preview
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: AspectRatio(
                                    aspectRatio: previewRatio,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _buildSingleMediaContent(
                                            theme, activeItem),
                                        // Top-Left: Active item index & type badge
                                        Positioned(
                                          left: 12,
                                          top: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.7),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: Colors.white24),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  activeItem.isVideo
                                                      ? Icons.videocam_rounded
                                                      : Icons
                                                          .photo_library_rounded,
                                                  color: activeItem.isVideo
                                                      ? const Color(0xFFF43F5E)
                                                      : Colors.white,
                                                  size: 15,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${_activeMediaIndex + 1} of ${_selectedMedia.length}',
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
                                        // Top-Right: Add more and Delete current buttons
                                        Positioned(
                                          right: 12,
                                          top: 12,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _CircleOverlayButton(
                                                icon: Icons.add_rounded,
                                                onTap: _showMediaPicker,
                                              ),
                                              const SizedBox(width: 8),
                                              _CircleOverlayButton(
                                                icon: Icons
                                                    .delete_outline_rounded,
                                                onTap: () {
                                                  setState(() {
                                                    _selectedMedia.removeAt(
                                                        _activeMediaIndex);
                                                    if (_activeMediaIndex >=
                                                        _selectedMedia.length) {
                                                      _activeMediaIndex =
                                                          (_selectedMedia.length -
                                                                  1)
                                                              .clamp(0, 9999);
                                                    }
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Left arrow to navigate previous (if > 0)
                                        if (_activeMediaIndex > 0)
                                          Positioned(
                                            left: 10,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: _CircleOverlayButton(
                                                icon:
                                                    Icons.chevron_left_rounded,
                                                onTap: () {
                                                  setState(() {
                                                    _activeMediaIndex--;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        // Right arrow to navigate next (if < length - 1)
                                        if (_activeMediaIndex <
                                            _selectedMedia.length - 1)
                                          Positioned(
                                            right: 10,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: _CircleOverlayButton(
                                                icon:
                                                    Icons.chevron_right_rounded,
                                                onTap: () {
                                                  setState(() {
                                                    _activeMediaIndex++;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        // Bottom-Right: Orientation toggle button
                                        Positioned(
                                          right: 12,
                                          bottom: 12,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (isVertical) {
                                                  activeItem.aspectRatio =
                                                      activeItem.isVideo
                                                          ? (16 / 9)
                                                          : (16 / 10);
                                                } else {
                                                  activeItem.aspectRatio =
                                                      activeItem.isVideo
                                                          ? (9 / 16)
                                                          : (4 / 5);
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.7),
                                                borderRadius:
                                                  BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isVertical
                                                        ? Icons
                                                            .stay_current_portrait_rounded
                                                        : Icons
                                                            .stay_current_landscape_rounded,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    isVertical
                                                        ? 'Vertical'
                                                        : 'Landscape',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  const Icon(
                                                    Icons.swap_horiz_rounded,
                                                    color: Colors.white70,
                                                    size: 14,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Bottom-Left: File name badge
                                        Positioned(
                                          left: 12,
                                          bottom: 12,
                                          child: Container(
                                            constraints: const BoxConstraints(
                                                maxWidth: 170),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.65),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              activeItem.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Horizontal Multi-Media Carousel Strip
                                SizedBox(
                                  height: 74,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _selectedMedia.length + 1,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      if (index == _selectedMedia.length) {
                                        return _buildAddMoreThumbnailTile(
                                            scheme);
                                      }
                                      return _buildMediaThumbnailTile(
                                        index,
                                        _selectedMedia[index],
                                        scheme,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      else
                        // Empty media placeholder button
                        GestureDetector(
                          onTap: _showMediaPicker,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.primary
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: scheme.primary,
                                      size: 34,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Select Photos or Videos',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pick multiple photos, reels, or videos from your device',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14),
                                        ),
                                        onPressed:
                                            _pickMultipleImagesFromGallery,
                                        icon: const Icon(
                                            Icons.photo_library_rounded,
                                            size: 16),
                                        label: const Text('Multi Photos'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14),
                                        ),
                                        onPressed:
                                            _pickMultipleVideosFromGallery,
                                        icon: const Icon(
                                            Icons.video_collection_rounded,
                                            size: 16),
                                        label: const Text('Videos'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Bar with Privacy Pill & Next / Post Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Audience pill (Friends / Public)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _privacy = _privacy == 'Friends' ? 'Public' : 'Friends';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _privacy == 'Friends'
                                ? Icons.people_rounded
                                : Icons.public_rounded,
                            color: scheme.onSurfaceVariant,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _privacy,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Primary Next / Post button
                  SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaSourceTile extends StatelessWidget {
  const _MediaSourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPillChip extends StatelessWidget {
  const _TopPillChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: highlighted
              ? Border.all(color: scheme.primary, width: 1.2)
              : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: highlighted ? scheme.primary : scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleOverlayButton extends StatelessWidget {
  const _CircleOverlayButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
