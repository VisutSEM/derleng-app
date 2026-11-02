import 'package:flutter/material.dart';

import '../../../models/place.dart';
import '../../../models/route_info.dart';
import '../../../models/travel_mode.dart';
import 'place_sheet.dart';

/// Top Turn-by-Turn Guidance Banner displayed during active in-app navigation.
class NavigationTopBar extends StatelessWidget {
  const NavigationTopBar({
    super.key,
    required this.place,
    required this.route,
    required this.stepIndex,
    required this.onNextStep,
    required this.onPreviousStep,
    required this.onOpenStepsList,
    required this.onExit,
  });

  final Place place;
  final RouteInfo? route;
  final int stepIndex;
  final VoidCallback onNextStep;
  final VoidCallback onPreviousStep;
  final VoidCallback onOpenStepsList;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final steps = route?.steps ?? const [];
    final hasSteps = steps.isNotEmpty;
    final currentStep = hasSteps
        ? steps[stepIndex.clamp(0, steps.length - 1)]
        : RouteStep(
            instruction: 'Head toward ${place.name}',
            distanceMeters: route?.distanceMeters ?? 0,
            durationSeconds: route?.durationSeconds ?? 0,
            location: place.location,
            maneuverType: 'depart',
          );

    final nextStep = (hasSteps && stepIndex + 1 < steps.length)
        ? steps[stepIndex + 1]
        : null;

    final distanceText = currentStep.distanceMeters > 0
        ? 'In ${currentStep.distanceLabel}'
        : 'Arriving';

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF0F172A),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Maneuver icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            currentStep.icon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 2. Step guidance text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                distanceText,
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentStep.instruction,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3. Actions: View steps & Exit
                        IconButton(
                          onPressed: onOpenStepsList,
                          tooltip: 'All directions',
                          icon: const Icon(
                            Icons.format_list_bulleted_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: onExit,
                          tooltip: 'Exit navigation',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFF87171),
                            size: 22,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),

                    // 4. Sub-banner: next maneuver teaser or step counter
                    if (hasSteps && steps.length > 1) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Step ${stepIndex + 1} of ${steps.length}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (nextStep != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Colors.white38,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Then: ${nextStep.instruction}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ] else
                              const Spacer(),
                            IconButton(
                              onPressed: stepIndex > 0 ? onPreviousStep : null,
                              icon: const Icon(Icons.arrow_back_ios_rounded, size: 12),
                              color: Colors.white70,
                              disabledColor: Colors.white24,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            ),
                            IconButton(
                              onPressed: stepIndex < steps.length - 1 ? onNextStep : null,
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                              color: Colors.white70,
                              disabledColor: Colors.white24,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom active trip summary and navigation controls.
class NavigationBottomBar extends StatelessWidget {
  const NavigationBottomBar({
    super.key,
    required this.place,
    required this.route,
    required this.mode,
    required this.onRecenter,
    required this.onOpenStepsList,
    required this.onExit,
  });

  final Place place;
  final RouteInfo? route;
  final TravelMode mode;
  final VoidCallback onRecenter;
  final VoidCallback onOpenStepsList;
  final VoidCallback onExit;

  String _formatEta(int durationSeconds) {
    final arrivalTime = DateTime.now().add(Duration(seconds: durationSeconds));
    final hour = arrivalTime.hour % 12 == 0 ? 12 : arrivalTime.hour % 12;
    final minute = arrivalTime.minute.toString().padLeft(2, '0');
    final period = arrivalTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = route;

    final durationText = info?.durationLabel ?? 'Calculating…';
    final distanceText = info?.distanceLabel ?? '';
    final etaText = info != null ? _formatEta(info.durationSeconds) : '';

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(24),
              color: scheme.surface,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    // Trip metrics & destination
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                durationText,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (etaText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: scheme.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  etaText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                              if (distanceText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: scheme.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  distanceText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                iconForMode(mode),
                                size: 14,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Controls: Re-center & End navigation
                    IconButton.filledTonal(
                      onPressed: onRecenter,
                      tooltip: 'Re-center camera',
                      icon: const Icon(Icons.near_me_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onExit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('End'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal Sheet showing all turn-by-turn guidance steps.
class NavigationStepsSheet extends StatelessWidget {
  const NavigationStepsSheet({
    super.key,
    required this.place,
    required this.route,
    required this.currentStepIndex,
    required this.onSelectStep,
  });

  final Place place;
  final RouteInfo? route;
  final int currentStepIndex;
  final ValueChanged<int> onSelectStep;

  static void show(
    BuildContext context, {
    required Place place,
    required RouteInfo? route,
    required int currentStepIndex,
    required ValueChanged<int> onSelectStep,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NavigationStepsSheet(
        place: place,
        route: route,
        currentStepIndex: currentStepIndex,
        onSelectStep: onSelectStep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final steps = route?.steps ?? const [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Turn-by-turn directions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'To ${place.name} • ${route?.distanceLabel ?? ""} • ${route?.durationLabel ?? ""}',
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
          ),
          const Divider(height: 1),
          Expanded(
            child: steps.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Follow route on map to ${place.name}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: steps.length,
                    separatorBuilder: (context, index) => const Divider(
                      indent: 56,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      final isCurrent = index == currentStepIndex;

                      return ListTile(
                        selected: isCurrent,
                        selectedTileColor: scheme.primary.withValues(alpha: 0.08),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            step.icon,
                            size: 20,
                            color: isCurrent
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          step.instruction,
                          style: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                        subtitle: step.distanceMeters > 0
                            ? Text('${step.distanceLabel} • ${step.durationLabel}')
                            : null,
                        trailing: isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          onSelectStep(index);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
