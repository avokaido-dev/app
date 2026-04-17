import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_service.dart';
import 'auth/sign_in_screen.dart';
import 'firebase_options.dart';
import 'invite/invite_landing_screen.dart';
import 'onboarding/create_workspace_screen.dart';
import 'workspace/overview_screen.dart';
import 'workspace/settings_screen.dart';
import 'workspace/team_screen.dart';
import 'workspace/workspace_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final auth = AuthService();
  runApp(AvokaidoApp(auth: auth));
}

class AvokaidoApp extends StatefulWidget {
  const AvokaidoApp({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AvokaidoApp> createState() => _AvokaidoAppState();
}

class _AvokaidoAppState extends State<AvokaidoApp> {
  late final GoRouter _router = GoRouter(
    refreshListenable: widget.auth,
    initialLocation: '/workspace/overview',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Public invite landing stays public regardless of auth state.
      if (loc.startsWith('/invite/')) return null;

      switch (widget.auth.status) {
        case AuthStatus.signedOut:
          return loc == '/signin' ? null : '/signin';
        case AuthStatus.signedInPending:
          // Keep showing the current route while claims load — a quick flash
          // of a spinner is tolerable and avoids route thrashing.
          return null;
        case AuthStatus.signedInNoWorkspace:
          return loc == '/create-workspace' ? null : '/create-workspace';
        case AuthStatus.signedInWithWorkspace:
          if (loc == '/signin' || loc == '/create-workspace') {
            return '/workspace/overview';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (_, __) => SignInScreen(auth: widget.auth),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (_, state) =>
            InviteLandingScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/create-workspace',
        builder: (_, __) => CreateWorkspaceScreen(auth: widget.auth),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            WorkspaceShell(auth: widget.auth, child: child),
        routes: [
          GoRoute(
            path: '/workspace/overview',
            builder: (_, __) => OverviewScreen(auth: widget.auth),
          ),
          GoRoute(
            path: '/workspace/team',
            builder: (_, __) => TeamScreen(auth: widget.auth),
          ),
          GoRoute(
            path: '/workspace/settings',
            builder: (_, __) => SettingsScreen(auth: widget.auth),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Avokaido',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
