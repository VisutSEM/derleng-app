import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/media_launcher.dart';
import '../../../core/utils/ui.dart';
import '../auth_controller.dart';

/// Modal dialog for Telegram sign-in & account connection.
class TelegramAuthDialog extends ConsumerStatefulWidget {
  const TelegramAuthDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TelegramAuthDialog(),
    );
  }

  @override
  ConsumerState<TelegramAuthDialog> createState() => _TelegramAuthDialogState();
}

class _TelegramAuthDialogState extends ConsumerState<TelegramAuthDialog> {
  final _usernameController = TextEditingController(text: 'sokha_chan');
  final _nameController = TextEditingController(text: 'Sokha Chan');
  bool _isConnecting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _connectWithTelegram() async {
    final rawHandle = _usernameController.text.trim();
    if (rawHandle.isEmpty) {
      showAppSnackBar(context, 'Please enter your Telegram username.', isError: true);
      return;
    }

    final handle = rawHandle.replaceAll('@', '');
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : handle;

    setState(() => _isConnecting = true);

    try {
      final success = await ref.read(authProvider.notifier).signInWithTelegram(
            username: handle,
            name: name,
            photoUrl:
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
          );

      if (!mounted) return;
      if (success) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).pop(true);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF7FE0C7),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Connected with Telegram @$handle!')),
                ],
              ),
            ),
          );
        }
      } else {
        setState(() => _isConnecting = false);
        final err = ref.read(authProvider).error ?? 'Could not connect Telegram.';
        showAppSnackBar(context, err, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        showAppSnackBar(context, 'Connection failed: $e', isError: true);
      }
    }
  }

  Future<void> _openTelegramBot() async {
    await launchMediaUrlSafely(
      context,
      'https://t.me/derleng_bot',
      failureMessage: 'Could not open Telegram.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const telegramBlue = Color(0xFF24A1DE);

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Telegram Icon Badge
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2AABEE),
                        Color(0xFF229ED9),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: telegramBlue.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title & Description
              Text(
                'Connect Telegram',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in instantly with your Telegram account to share and discover travel stories in Cambodia.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),

              // Username input
              TextField(
                controller: _usernameController,
                enabled: !_isConnecting,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Telegram Username',
                  hintText: 'username',
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    color: telegramBlue,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Display Name input
              TextField(
                controller: _nameController,
                enabled: !_isConnecting,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _connectWithTelegram(),
                decoration: InputDecoration(
                  labelText: 'Display Name (optional)',
                  hintText: 'e.g. Sokha Chan',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Connect Button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: telegramBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isConnecting ? null : _connectWithTelegram,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isConnecting ? 'Connecting…' : 'Continue with Telegram',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Optional Open in Telegram link
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: telegramBlue,
                ),
                onPressed: _isConnecting ? null : _openTelegramBot,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open Derleng Telegram Bot'),
              ),

              const SizedBox(height: 4),

              // Cancel button
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
