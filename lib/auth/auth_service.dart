import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Status of the user's current session, driving the router.
enum AuthStatus {
  /// No Firebase user.
  signedOut,

  /// Signed in, but we haven't read custom claims yet.
  signedInPending,

  /// Signed in and needs to create (or join) a workspace.
  signedInNoWorkspace,

  /// Signed in and belongs to a workspace.
  signedInWithWorkspace,
}

/// Wraps [FirebaseAuth] to expose a simple status stream for go_router.
///
/// End users sign in via GitHub, Microsoft, or Apple OAuth. There's no
/// email/password or Google option — this is a developer-focused product
/// and the providers reflect that.
class AuthService extends ChangeNotifier {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  final FirebaseAuth _auth;

  AuthStatus _status = AuthStatus.signedOut;
  User? _user;
  String? _workspaceId;
  String? _workspaceRole;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get workspaceId => _workspaceId;
  String? get workspaceRole => _workspaceRole;
  bool get isOrgAdmin => _workspaceRole == 'admin';
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Sign-in entry points
  // ---------------------------------------------------------------------------

  Future<void> signInWithGithub() => _signInWith(GithubAuthProvider());

  Future<void> signInWithMicrosoft() =>
      _signInWith(OAuthProvider('microsoft.com'));

  Future<void> signInWithApple() => _signInWith(OAuthProvider('apple.com'));

  Future<void> _signInWith(AuthProvider provider) async {
    _errorMessage = null;
    try {
      await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.code;
      notifyListeners();
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Forces the ID token to refresh so custom claims (e.g. a just-created
  /// workspaceId) propagate immediately instead of waiting for the 1-hour
  /// token rotation.
  Future<void> refreshClaims() async {
    if (_user == null) return;
    await _user!.getIdToken(true);
    await _onAuthChanged(_auth.currentUser);
  }

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    if (user == null) {
      _status = AuthStatus.signedOut;
      _workspaceId = null;
      _workspaceRole = null;
      notifyListeners();
      return;
    }

    _status = AuthStatus.signedInPending;
    notifyListeners();

    // Force-refresh to pull the freshest custom claims.
    final token = await user.getIdTokenResult(true);
    _workspaceId = token.claims?['workspaceId'] as String?;
    _workspaceRole = token.claims?['workspaceRole'] as String?;
    _status = (_workspaceId == null || _workspaceId!.isEmpty)
        ? AuthStatus.signedInNoWorkspace
        : AuthStatus.signedInWithWorkspace;
    notifyListeners();
  }
}
