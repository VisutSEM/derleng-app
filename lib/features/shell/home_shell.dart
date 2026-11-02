import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/place.dart';
import '../explore/explore_controller.dart';
import '../explore/explore_screen.dart';
import '../favorites/favorites_controller.dart';
import '../favorites/saved_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const int _exploreIndex = 1;

  int _index = 0;

  void _openPlace(Place place) {
    ref.read(exploreProvider.notifier).selectPlace(place);
    setState(() => _index = _exploreIndex);
  }

  @override
  Widget build(BuildContext context) {
    final savedCount = ref.watch(favoritesProvider).length;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenPlace: _openPlace,
            onExplore: () => setState(() => _index = _exploreIndex),
            onOpenProfile: () => setState(() => _index = 3),
          ),
          const ExploreScreen(),
          SavedScreen(
            onOpenPlace: _openPlace,
            onBrowse: () => setState(() => _index = _exploreIndex),
          ),
          ProfileScreen(onOpenPlace: _openPlace),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: savedCount,
              isLabelVisible: savedCount > 0,
              child: const Icon(Icons.bookmark_border_rounded),
            ),
            selectedIcon: Badge.count(
              count: savedCount,
              isLabelVisible: savedCount > 0,
              child: const Icon(Icons.bookmark_rounded),
            ),
            label: 'Saved',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
