import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_video_player_modal.dart';
import '../../data/providers.dart';
import '../../models/app_settings.dart';
import '../../models/place.dart';
import '../../models/place_post.dart';
import '../auth/auth_controller.dart';
import '../explore/widgets/place_visuals.dart';
import '../favorites/favorites_controller.dart';
import '../home/feed_controller.dart';
import '../home/widgets/new_post_screen.dart';
import '../home/widgets/post_card.dart';
import '../home/widgets/post_detail_screen.dart';
import '../settings/settings_controller.dart';
import 'widgets/edit_post_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.onOpenPlace});

  final ValueChanged<Place>? onOpenPlace;

  static const List<Map<String, String>> _sampleAvatars = [
    {
      'label': 'Angkor Sunrise',
      'url':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Phnom Penh Rider',
      'url':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Island Wanderer',
      'url':
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Heritage Guide',
      'url':
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Mountain Hiker',
      'url':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
    },
    {
      'label': 'Coffee Explorer',
      'url':
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final settings = ref.watch(settingsProvider);
    final feed = ref.watch(feedProvider);
    final favorites = ref.watch(favoritesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final userName = user?.name.trim().toLowerCase() ?? '';
    final myPosts = feed.posts.where((post) {
      final author = post.authorName.trim().toLowerCase();
      if (userName.isNotEmpty) {
        return author == userName;
      }
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _ProfileHeader(
            name: user?.name ?? 'Traveler',
            email: user?.email ?? '',
            initials: user?.initials ?? '?',
            provider: user?.provider ?? 'password',
            photoUrl: user?.photoUrl,
            onTapPhoto: () => _pickProfilePhoto(
              context,
              ref,
              currentPhotoUrl: user?.photoUrl,
            ),
          ),
          const SizedBox(height: 14),
          _ProfileStatsRow(
            postsCount: myPosts.length,
            savedCount: favorites.length,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const _SectionLabel('My Stories'),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${myPosts.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => NewPostScreen.show(context),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Post place'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (myPosts.isEmpty)
            _EmptyStoriesCard(onPost: () => NewPostScreen.show(context))
          else
            for (final post in myPosts)
              _MyStoryCard(
                post: post,
                userPhotoUrl: user?.photoUrl,
                onEdit: () => _editPost(context, post),
                onDelete: () => _deletePost(context, ref, post),
                onOpenPlace: onOpenPlace,
              ),
          const SizedBox(height: 20),
          const _SectionLabel('Preferences'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance'),
                  subtitle: Text(_themeLabel(settings.themeMode)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickTheme(context, ref, settings),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('API base URL'),
                  subtitle: Text(
                    settings.apiBaseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editBaseUrl(context, ref, settings),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.wifi_tethering_rounded),
                  title: const Text('Test API connection'),
                  subtitle: const Text('Ping the /health endpoint'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _testConnection(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Map provider'),
                  subtitle: Text(
                    AppConfig.hasGoogleMapsKey
                        ? 'Google Maps (key configured)'
                        : 'Interactive preview — add a Maps key for live tiles',
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Backend setup'),
                  subtitle: const Text('Endpoints expected by this UI'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showBackendGuide(context),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.tag_rounded),
                  title: const Text('Version'),
                  subtitle: const Text(AppConfig.appVersion),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            ),
            onPressed: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Sign out?',
                message: 'You will need to sign in again to use Derleng.',
                confirmLabel: 'Sign out',
                destructive: true,
              );
              if (!confirmed || !context.mounted) return;
              await ref.read(authProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfilePhoto(
    BuildContext context,
    WidgetRef ref, {
    String? currentPhotoUrl,
  }) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final imagePicker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose a photo to represent you on Derleng',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: scheme.primary,
                    ),
                  ),
                  title: const Text('Choose from gallery'),
                  subtitle: const Text('Select an image from your photo album'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    try {
                      final picked = await imagePicker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 88,
                      );
                      if (picked != null) {
                        await ref
                            .read(authProvider.notifier)
                            .updateProfilePhoto(picked.path);
                        if (!context.mounted) return;
                        showAppSnackBar(context, 'Profile photo updated!');
                      }
                    } catch (e) {
                      try {
                        final files =
                            await FilePickerPlatform.instance.pickFiles(
                          type: FileType.image,
                        );
                        if (files.isNotEmpty && files.first.path != null) {
                          await ref
                              .read(authProvider.notifier)
                              .updateProfilePhoto(files.first.path!);
                          if (!context.mounted) return;
                          showAppSnackBar(context, 'Profile photo updated!');
                          return;
                        }
                      } catch (_) {}
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        'Could not access gallery: $e',
                        isError: true,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.secondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: scheme.secondary,
                    ),
                  ),
                  title: const Text('Take a photo'),
                  subtitle: const Text('Use camera to take a new picture'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    try {
                      final picked = await imagePicker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 88,
                      );
                      if (picked != null) {
                        await ref
                            .read(authProvider.notifier)
                            .updateProfilePhoto(picked.path);
                        if (!context.mounted) return;
                        showAppSnackBar(context, 'Profile photo updated!');
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        'Could not open camera: $e',
                        isError: true,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.folder_open_outlined,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  title: const Text('Choose from file'),
                  subtitle: const Text('Browse device files or downloads'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    try {
                      final files =
                          await FilePickerPlatform.instance.pickFiles(
                        type: FileType.image,
                      );
                      if (files.isNotEmpty && files.first.path != null) {
                        await ref
                            .read(authProvider.notifier)
                            .updateProfilePhoto(files.first.path!);
                        if (!context.mounted) return;
                        showAppSnackBar(context, 'Profile photo updated!');
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        'Could not pick file: $e',
                        isError: true,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  title: const Text('Choose sample avatar'),
                  subtitle: const Text('Pick from curated traveler presets'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _showSampleAvatarsDialog(context, ref);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.link_rounded, color: scheme.tertiary),
                  ),
                  title: const Text('Web image URL'),
                  subtitle: const Text('Paste an image URL directly'),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _showImageUrlDialog(
                      context,
                      ref,
                      initialUrl: currentPhotoUrl,
                    );
                  },
                ),
                if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) ...[
                  const Divider(height: 12),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: scheme.error,
                      ),
                    ),
                    title: Text(
                      'Remove profile photo',
                      style: TextStyle(color: scheme.error),
                    ),
                    subtitle: const Text('Revert to default initials avatar'),
                    onTap: () async {
                      Navigator.of(bottomSheetContext).pop();
                      await ref
                          .read(authProvider.notifier)
                          .updateProfilePhoto(null);
                      if (!context.mounted) return;
                      showAppSnackBar(context, 'Profile photo removed.');
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSampleAvatarsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Choose a travel avatar'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _sampleAvatars.length,
              itemBuilder: (context, index) {
                final item = _sampleAvatars[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await ref
                        .read(authProvider.notifier)
                        .updateProfilePhoto(item['url']);
                    if (!context.mounted) return;
                    showAppSnackBar(context, 'Profile photo updated!');
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipOval(
                          child: Image.network(
                            item['url']!,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                            errorBuilder: (_, _, _) => CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.15),
                              child: Icon(Icons.person, color: scheme.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImageUrlDialog(
    BuildContext context,
    WidgetRef ref, {
    String? initialUrl,
  }) async {
    final controller = TextEditingController(text: initialUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Image URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com/photo.jpg',
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    await ref.read(authProvider.notifier).updateProfilePhoto(url);
    if (!context.mounted) return;
    showAppSnackBar(context, 'Profile photo updated!');
  }

  Future<void> _editPost(BuildContext context, PlacePost post) async {
    await EditPostSheet.show(context, post: post);
  }

  Future<void> _deletePost(
    BuildContext context,
    WidgetRef ref,
    PlacePost post,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this post?',
      message:
          'Are you sure you want to delete your post about "${post.place.name}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(feedProvider.notifier).deletePost(post.id);
      if (!context.mounted) return;
      showAppSnackBar(context, 'Story deleted.');
    } catch (_) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Could not delete story. Try again.',
        isError: true,
      );
    }
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System default',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Appearance'),
        children: ThemeMode.values.map((mode) {
          final selected = mode == settings.themeMode;
          return ListTile(
            leading: Icon(switch (mode) {
              ThemeMode.system => Icons.brightness_auto_rounded,
              ThemeMode.light => Icons.light_mode_rounded,
              ThemeMode.dark => Icons.dark_mode_rounded,
            }),
            title: Text(_themeLabel(mode)),
            trailing: selected
                ? const Icon(Icons.check_rounded, color: Color(0xFF0F766E))
                : null,
            onTap: () => Navigator.of(context).pop(mode),
          );
        }).toList(growable: false),
      ),
    );
    if (selected == null) return;
    await ref.read(settingsProvider.notifier).setThemeMode(selected);
  }

  Future<void> _editBaseUrl(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _BaseUrlDialog(initialValue: settings.apiBaseUrl),
    );
    if (value == null || value.trim().isEmpty) return;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Enter a full URL, e.g. https://api.site.com/api',
        isError: true,
      );
      return;
    }
    await ref.read(settingsProvider.notifier).setApiBaseUrl(value);
    if (!context.mounted) return;
    showAppSnackBar(context, 'API base URL updated.');
  }

  Future<void> _testConnection(BuildContext context, WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Checking ${client.baseUrl} …'),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final elapsed = await client.ping();
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
              SizedBox(width: 10),
              Text('API reachable'),
            ],
          ),
          content: Text(
            '${client.baseUrl}\nResponded in ${elapsed.inMilliseconds} ms.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text('Cannot reach API'),
            ],
          ),
          content: Text('${error.message}\n\n${client.baseUrl}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showBackendGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        const endpoints = [
          'GET    /places/search?q=',
          'GET    /places/nearby?lat=&lng=&category=',
          'GET    /feed?sort=trending&limit=',
          'GET    /directions?origin=&destination=&mode=',
          'POST   /auth/login',
          'POST   /auth/register',
          'POST   /auth/forgot-password',
          'POST   /auth/logout',
          'GET    /favorites',
          'POST   /favorites',
          'DELETE /favorites/{id}',
          'GET    /health',
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend setup', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Point the app at your Laravel API with a dart-define or the field above. '
                  'The UI reads these endpoints:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final endpoint in endpoints)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            endpoint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'flutter run --dart-define=API_BASE_URL=https://api.example.com/api '
                  '--dart-define=DEMO_MODE=false',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.initials,
    required this.provider,
    this.photoUrl,
    this.onTapPhoto,
  });

  final String name;
  final String email;
  final String initials;
  final String provider;
  final String? photoUrl;
  final VoidCallback? onTapPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, const Color(0xFF0B5F58)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProfileAvatar(
            initials: initials,
            photoUrl: photoUrl,
            onTap: onTapPhoto,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider == 'telegram') ...[
                            const Icon(
                              Icons.send_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            provider == 'google'
                                ? 'Google account'
                                : (provider == 'telegram'
                                    ? 'Telegram account'
                                    : 'Email account'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onTapPhoto,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              photoUrl != null
                                  ? 'Edit photo'
                                  : 'Upload photo',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    this.photoUrl,
    this.onTap,
  });

  final String initials;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final url = photoUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    Widget imageContent;
    if (!hasUrl) {
      imageContent = Center(
        child: Text(
          initials,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageContent = Image.network(
        url,
        fit: BoxFit.cover,
        width: 68,
        height: 68,
        errorBuilder: (_, _, _) => Center(
          child: Text(
            initials,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else if (!kIsWeb && File(url).existsSync()) {
      imageContent = Image.file(
        File(url),
        fit: BoxFit.cover,
        width: 68,
        height: 68,
        errorBuilder: (_, _, _) => Center(
          child: Text(
            initials,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else {
      imageContent = Center(
        child: Text(
          initials,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: ClipOval(child: imageContent),
            ),
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({
    required this.postsCount,
    required this.savedCount,
  });

  final int postsCount;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            count: '$postsCount',
            label: 'Stories',
            icon: Icons.dynamic_feed_rounded,
            color: scheme.primary,
          ),
          Container(
            height: 32,
            width: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          _StatItem(
            count: '$savedCount',
            label: 'Saved places',
            icon: Icons.bookmark_rounded,
            color: const Color(0xFFD97706),
          ),
          Container(
            height: 32,
            width: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const _StatItem(
            count: 'Cambodia',
            label: 'Region',
            icon: Icons.explore_rounded,
            color: Color(0xFF0F766E),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String count;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              count,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyStoriesCard extends StatelessWidget {
  const _EmptyStoriesCard({required this.onPost});

  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 32,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No stories shared yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share your favorite destinations, foods, and tips with other travelers.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onPost,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Share your first story'),
          ),
        ],
      ),
    );
  }
}

class _MyStoryCard extends StatelessWidget {
  const _MyStoryCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
    this.onOpenPlace,
    this.userPhotoUrl,
  });

  final PlacePost post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Place>? onOpenPlace;
  final String? userPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasMedia =
        post.thumbnailUrl != null && post.thumbnailUrl!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                AuthorAvatar(
                  name: post.authorName,
                  photoUrl: post.authorAvatarUrl ?? userPhotoUrl,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            iconForCategory(post.place.category),
                            size: 14,
                            color: colorForCategory(post.place.category),
                          ),
                        ],
                      ),
                      Text(
                        formatRelativeTime(post.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit story',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: scheme.error,
                  ),
                  tooltip: 'Delete story',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          if (hasMedia)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AdaptivePostMedia(
                post: post,
                borderRadius: 14,
                onPlay: (post.isVideo && post.videoUrl != null)
                    ? () => AppVideoPlayerModal.show(
                          context,
                          videoUrl: post.videoUrl!,
                          title: post.place.name,
                          authorName: post.authorName,
                        )
                    : null,
                onTap: () {
                  PostDetailScreen.show(
                    context,
                    post: post,
                    onOpenPlace: onOpenPlace ?? (_) {},
                  );
                },
              ),
            ),
          InkWell(
            onTap: () {
              PostDetailScreen.show(
                context,
                post: post,
                onOpenPlace: onOpenPlace ?? (_) {},
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption.isNotEmpty) ...[
                    Text(
                      post.caption,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 12, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, size: 15, color: scheme.primary),
                const SizedBox(width: 4),
                Text('${post.likes}', style: theme.textTheme.labelSmall),
                const SizedBox(width: 14),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text('${post.comments}', style: theme.textTheme.labelSmall),
                const Spacer(),
                if (onOpenPlace != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => onOpenPlace!(post.place),
                    icon: const Icon(Icons.explore_outlined, size: 16),
                    label: const Text('View on map'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _BaseUrlDialog extends StatefulWidget {
  const _BaseUrlDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_BaseUrlDialog> createState() => _BaseUrlDialogState();
}

class _BaseUrlDialogState extends State<_BaseUrlDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API base URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Include the /api prefix used by your Laravel routes.'),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com/api',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Presets for Android device:',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('USB / Reverse ADB'),
                onPressed: () => setState(() {
                  _controller.text = 'http://127.0.0.1:8000/api';
                }),
              ),
              ActionChip(
                label: const Text('Wi-Fi (192.168.8.179)'),
                onPressed: () => setState(() {
                  _controller.text = 'http://192.168.8.179:8000/api';
                }),
              ),
              ActionChip(
                label: const Text('Emulator (10.0.2.2)'),
                onPressed: () => setState(() {
                  _controller.text = 'http://10.0.2.2:8000/api';
                }),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
