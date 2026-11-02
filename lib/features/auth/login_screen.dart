import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/ui.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../settings/settings_controller.dart';
import 'auth_controller.dart';
import 'register_screen.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/telegram_auth_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  Future<void> _googleSignIn() async {
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  Future<void> _telegramSignIn() async {
    FocusScope.of(context).unfocus();
    await TelegramAuthDialog.show(context);
  }

  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => _ResetPasswordDialog(initialEmail: _email.text),
    );
    if (email == null || email.isEmpty || !mounted) return;
    final error =
        await ref.read(authProvider.notifier).sendPasswordReset(email);
    if (!mounted) return;
    showAppSnackBar(
      context,
      error ?? 'Password reset link sent to $email',
      isError: error != null,
    );
  }

  void _fillDemoAccount() {
    setState(() {
      _email.text = 'sokha.chan@derleng.app';
      _password.text = 'derleng123';
    });
    ref.read(authProvider.notifier).clearError();
  }

  void _openRegister() {
    ref.read(authProvider.notifier).clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AuthScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthBrandHeader(
            title: 'Derleng',
            subtitle: 'Find any place. Get there faster.',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome back', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to keep exploring.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(
                      message: auth.error!,
                      onDismiss: () =>
                          ref.read(authProvider.notifier).clearError(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _email,
                    enabled: !auth.busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: validateEmail,
                    onChanged: (_) =>
                        ref.read(authProvider.notifier).clearError(),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    enabled: !auth.busy,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: validatePassword,
                    onFieldSubmitted: (_) => _submit(),
                    onChanged: (_) =>
                        ref.read(authProvider.notifier).clearError(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: auth.busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  PrimaryButton(
                    label: 'Sign in',
                    loading: auth.busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: auth.busy ? null : _googleSignIn,
                    icon: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 30,
                      color: Color(0xFF4285F4),
                    ),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF24A1DE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: auth.busy ? null : _telegramSignIn,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'Continue with Telegram',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (settings.demoMode) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: auth.busy ? null : _fillDemoAccount,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Use demo account'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'New to Derleng?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: auth.busy ? null : _openRegister,
                child: const Text('Create account'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (settings.demoMode)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Demo mode — any email and a 6+ character password works.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialEmail.trim());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the email linked to your account and we will send a reset link.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Send link'),
        ),
      ],
    );
  }
}
