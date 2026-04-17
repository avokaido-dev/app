import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';

class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({super.key, required this.child, required this.auth});
  final Widget child;
  final AuthService auth;

  static const _destinations = [
    _NavItem('/workspace/overview', Icons.dashboard_outlined, 'Overview'),
    _NavItem('/workspace/team', Icons.group_outlined, 'Team'),
    _NavItem('/workspace/settings', Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex =
        _destinations.indexWhere((d) => location.startsWith(d.route));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avokaido'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                auth.user?.email ?? '',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) =>
                context.go(_destinations[i].route),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.route, this.icon, this.label);
  final String route;
  final IconData icon;
  final String label;
}
