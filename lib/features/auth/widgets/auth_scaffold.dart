import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.showBack = false,
  });

  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = showBack ? 56.0 : 24.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0C1A16),
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor,
                        ]
                      : [
                          const Color(0xFFE6F4EF),
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor,
                        ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: _Glow(
              size: 240,
              color: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _Glow(
              size: 300,
              color: scheme.tertiary.withValues(alpha: isDark ? 0.16 : 0.10),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bottomInset =
                        MediaQuery.viewInsetsOf(context).bottom;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        topPadding,
                        24,
                        24 + bottomInset,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - topPadding - 24)
                              .clamp(0, double.infinity),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (showBack)
                  Positioned(
                    top: 4,
                    left: 8,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoSize = 64,
  });

  final String title;
  final String subtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
