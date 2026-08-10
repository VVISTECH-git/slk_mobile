import 'package:flutter/material.dart';

/// The home-screen layouts a user can pick between. Saved per device (like the
/// theme), so each person keeps their preferred view.
enum HomeLayout { grid, bottomNav, list, dashboard, bigButtons }

class HomeLayoutMeta {
  const HomeLayoutMeta(this.layout, this.label, this.description, this.icon);
  final HomeLayout layout;
  final String label;
  final String description;
  final IconData icon;
}

const homeLayouts = <HomeLayoutMeta>[
  HomeLayoutMeta(HomeLayout.grid, 'Card grid', 'Spacious tiles — the classic look', Icons.grid_view_rounded),
  HomeLayoutMeta(HomeLayout.bottomNav, 'Bottom bar', 'Quick shortcuts always at the bottom', Icons.space_dashboard_outlined),
  HomeLayoutMeta(HomeLayout.list, 'Compact list', 'Dense rows with live badges', Icons.view_list_rounded),
  HomeLayoutMeta(HomeLayout.dashboard, 'Dashboard first', "Today's numbers up top", Icons.insights_rounded),
  HomeLayoutMeta(HomeLayout.bigButtons, 'Big buttons', 'Large, easy tap targets', Icons.apps_rounded),
];

HomeLayoutMeta homeLayoutMeta(HomeLayout l) => homeLayouts.firstWhere((m) => m.layout == l);

HomeLayout homeLayoutById(String? id) =>
    HomeLayout.values.firstWhere((l) => l.name == id, orElse: () => HomeLayout.grid);
