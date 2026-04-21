import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';

class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({super.key, required this.child, required this.auth});
  final Widget child;
  final AuthService auth;

  static const _adminDestinations = [
    _NavItem('/workspace/releases', Icons.system_update_outlined, 'Releases'),
    _NavItem('/workspace/costs', Icons.payments_outlined, 'Costs'),
    _NavItem('/workspace/billing', Icons.receipt_long_outlined, 'Billing'),
    _NavItem('/workspace/team', Icons.group_outlined, 'Team'),
    _NavItem('/workspace/settings', Icons.settings_outlined, 'Settings'),
  ];

  static const _memberDestinations = [
    _NavItem('/workspace/download', Icons.download_outlined, 'Get the app'),
  ];

  @override
  Widget build(BuildContext context) {
    final isLoadingWorkspace =
        auth.status == AuthStatus.signedInPending || auth.workspaceId == null;
    final destinations = auth.isOrgAdmin
        ? _adminDestinations
        : _memberDestinations;
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = destinations.indexWhere(
      (d) => location.startsWith(d.route),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InkWell(
              onTap: () => context.go('/signin'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text('Avokaido'),
              ),
            ),
            if (auth.isOrgAdmin) ...[
              const SizedBox(width: 12),
              const Chip(
                label: Text('Admin', style: TextStyle(fontSize: 11)),
                avatar: Icon(Icons.shield_outlined, size: 14),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
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
          if (!isLoadingWorkspace && destinations.length > 1)
            NavigationRail(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => context.go(destinations[i].route),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
          if (!isLoadingWorkspace && destinations.length > 1)
            const VerticalDivider(width: 1),
          Expanded(
            child: isLoadingWorkspace ? const _LoadingWorkspaceView() : child,
          ),
        ],
      ),
    );
  }
}

class _LoadingWorkspaceView extends StatelessWidget {
  const _LoadingWorkspaceView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
          SizedBox(height: 14),
          Text(
            'Loading your workspace…',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
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
