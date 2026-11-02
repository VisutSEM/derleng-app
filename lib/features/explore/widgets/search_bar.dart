import 'package:flutter/material.dart';

class ExploreSearchBar extends StatelessWidget {
  const ExploreSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onCancel,
    required this.focused,
    required this.hasText,
    required this.loading,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final bool focused;
  final bool hasText;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Material(
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            color: scheme.surface,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Where do you want to go?',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: loading
                    ? Padding(
                        padding: const EdgeInsets.all(15),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                      )
                    : hasText
                        ? IconButton(
                            onPressed: onClear,
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded, size: 20),
                          )
                        : null,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.centerLeft,
          child: focused
              ? Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
