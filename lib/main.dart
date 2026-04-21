import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_service.dart';
import 'auth/sign_in_screen.dart';
import 'firebase_options.dart';
import 'investors/investors_screen.dart';
import 'invite/invite_landing_screen.dart';
import 'onboarding/create_workspace_screen.dart';
import 'tutorial/tutorial_screen.dart';
import 'workspace/billing_screen.dart';
import 'workspace/costs_screen.dart';
import 'workspace/download_screen.dart';
import 'workspace/releases_screen.dart';
import 'workspace/settings_screen.dart';
import 'workspace/team_screen.dart';
import 'workspace/workspace_shell.dart';

const _useEmulators = bool.fromEnvironment(
  'USE_EMULATORS',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_useEmulators) {
    debugPrint('[avokaido_app] Using local Firebase emulators.');
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }
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
  static const _adminHome = '/workspace/costs';
  static const _memberHome = '/workspace/download';
  static const _adminOnlyRoutes = <String>{
    '/workspace/costs',
    '/workspace/billing',
    '/workspace/team',
    '/workspace/releases',
    '/workspace/settings',
  };

  late final GoRouter _router = GoRouter(
    refreshListenable: widget.auth,
    initialLocation: _adminHome,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Public pages stay public regardless of auth state.
      if (loc.startsWith('/invite/')) return null;
      if (loc == '/investors') return null;
      if (loc == '/tutorial') return null;

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
          final home = widget.auth.isOrgAdmin ? _adminHome : _memberHome;
          if (loc == '/create-workspace') {
            return home;
          }
          // Members can't reach admin-only screens.
          if (!widget.auth.isOrgAdmin && _adminOnlyRoutes.contains(loc)) {
            return _memberHome;
          }
          // Admins hitting the member download redirect to their home.
          if (widget.auth.isOrgAdmin && loc == _memberHome) {
            return _adminHome;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (_, __) => SignInScreen(auth: widget.auth),
      ),
      GoRoute(path: '/investors', builder: (_, __) => const InvestorsScreen()),
      GoRoute(path: '/tutorial', builder: (_, __) => const TutorialScreen()),
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
            path: '/workspace/costs',
            builder: (_, __) => CostsScreen(auth: widget.auth),
          ),
          GoRoute(
            path: '/workspace/billing',
            builder: (_, __) => BillingScreen(auth: widget.auth),
          ),
          GoRoute(
            path: '/workspace/team',
            builder: (_, __) => TeamScreen(auth: widget.auth),
          ),
          GoRoute(
            path: '/workspace/releases',
            builder: (_, __) => ReleasesScreen(auth: widget.auth),
          ),
          GoRoute(
            path: '/workspace/settings',
            builder: (_, __) => SettingsScreen(auth: widget.auth),
          ),
          GoRoute(
            path: '/workspace/download',
            builder: (_, __) => DownloadScreen(auth: widget.auth),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Avokaido',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      routerConfig: _router,
    );
  }
}
