import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

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
/// End users sign in via GitHub, Google, Microsoft, or Apple OAuth, with
/// email/password as a fallback.
class AuthService extends ChangeNotifier {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _auth.authStateChanges().listen(_onAuthChanged);
    _handlePendingRedirect();
    _handlePendingEmailLink();
  }

  static const _pendingEmailKey = 'avokaido.pendingEmailLinkEmail';
  static const _sessionCollection = 'userSessions';
  static int _sessionCounter = 0;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthStatus _status = AuthStatus.signedOut;
  User? _user;
  String? _workspaceId;
  String? _workspaceRole;
  String? _errorMessage;
  String? _sessionId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;
  Timer? _sessionHeartbeat;
  bool _handlingForcedSignOut = false;
  bool _sessionTrackingAvailable = true;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get workspaceId => _workspaceId;
  String? get workspaceRole => _workspaceRole;
  bool get isOrgAdmin => _workspaceRole == 'admin';
  String? get errorMessage => _errorMessage;

  bool _pendingEmailLinkNeedsEmail = false;
  bool get pendingEmailLinkNeedsEmail => _pendingEmailLinkNeedsEmail;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sign-in entry points
  // ---------------------------------------------------------------------------

  Future<void> signInWithGithub() => _signInWith(GithubAuthProvider());

  Future<void> signInWithGoogle() => _signInWith(
        GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters(const {'prompt': 'select_account'}),
      );

  Future<void> signInWithMicrosoft() =>
      _signInWith(OAuthProvider('microsoft.com'));

  // Apple web sign-in requires the `email` and `name` scopes to be requested
  // explicitly, otherwise Firebase returns no user profile data.
  Future<void> signInWithApple() => _signInWith(
        OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name'),
      );

  // Picks up the OAuth result after a redirect-based sign-in completes.
  // Errors (e.g. provider not configured) surface here rather than in
  // _signInWith, because the page navigates away before _signInWith returns.
  Future<void> _handlePendingRedirect() async {
    try {
      await _auth.getRedirectResult();
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.code;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Passwordless invite links: the admin's `sendInvite` function emails a
  // `generateSignInWithEmailLink` URL that redirects back to `/signin?...`.
  // We detect the link on load and — if the email is cached from the same
  // browser — complete the sign-in automatically. If not (e.g. the recipient
  // clicked the link on a different device), we flip a flag so the UI can
  // prompt them to type their email, then call [completeEmailLinkSignIn].
  Future<void> _handlePendingEmailLink() async {
    final currentUrl = web.window.location.href;
    if (!_auth.isSignInWithEmailLink(currentUrl)) return;

    final cachedEmail =
        web.window.localStorage.getItem(_pendingEmailKey);
    if (cachedEmail != null && cachedEmail.isNotEmpty) {
      await completeEmailLinkSignIn(cachedEmail);
    } else {
      _pendingEmailLinkNeedsEmail = true;
      notifyListeners();
    }
  }

  Future<void> completeEmailLinkSignIn(String email) async {
    _errorMessage = null;
    final currentUrl = web.window.location.href;
    try {
      await _auth.signInWithEmailLink(
        email: email.trim(),
        emailLink: currentUrl,
      );
      web.window.localStorage.removeItem(_pendingEmailKey);
      _pendingEmailLinkNeedsEmail = false;
      // Strip the long query string from the address bar once consumed.
      web.window.history.replaceState(null, '', '/#/signin');
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.code;
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _signInWith(AuthProvider provider) async {
    clearError();
    try {
      if (kIsWeb) {
        try {
          await _auth.signInWithPopup(provider);
          return;
        } on FirebaseAuthException catch (e) {
          final code = e.code.toLowerCase();
          final shouldFallbackToRedirect =
              code == 'popup-blocked' ||
              code == 'popup_closed_by_user' ||
              code == 'cancelled-popup-request' ||
              code == 'web-context-cancelled';
          if (!shouldFallbackToRedirect) rethrow;
        }
      }

      await _auth.signInWithRedirect(provider);
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.code;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Email+password is a fallback path — OAuth (GitHub / Microsoft / Apple)
  // is the primary sign-in method.

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    clearError();
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      notifyListeners();
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    clearError();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      notifyListeners();
    }
  }

  /// Firebase returns `invalid-credential` for any email/password failure
  /// (wrong password, no account, or an OAuth-only account without a
  /// password). Surface a clearer action so users know what to try next.
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return "Couldn't sign in with that email + password. "
            'If you originally signed up with Google, GitHub, Microsoft, '
            'or Apple, use that button above. Otherwise, tap '
            '"Forgot password?" to set one.';
      case 'email-already-in-use':
        return 'An account with this email already exists — sign in '
            'instead, or use "Forgot password?" to reset it.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return "That doesn't look like a valid email address.";
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      default:
        return e.message ?? e.code;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _errorMessage = null;
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.code;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    clearError();
    await _signOutInternal(clearSessionDoc: true);
  }

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
      _stopSessionTracking();
      _status = AuthStatus.signedOut;
      _workspaceId = null;
      _workspaceRole = null;
      notifyListeners();
      return;
    }

    _status = AuthStatus.signedInPending;
    notifyListeners();

    final sessionOk = await _registerSession(user);
    if (!sessionOk || _auth.currentUser?.uid != user.uid) return;

    // Force-refresh to pull the freshest custom claims.
    var token = await user.getIdTokenResult(true);
    _workspaceId = token.claims?['workspaceId'] as String?;
    _workspaceRole = token.claims?['workspaceRole'] as String?;

    // No workspace yet — ask the backend whether the caller's email domain
    // already maps to an org. If it does, the function auto-joins them as a
    // member and we re-read claims. If not, fall through to the create-
    // workspace flow (where they'll become the admin for their domain).
    //
    // Hard timeout so a missing / misconfigured function never strands the
    // UI in `signedInPending` — we'd rather route to create-workspace than
    // show a blank loading state indefinitely.
    if (_workspaceId == null || _workspaceId!.isEmpty) {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('resolveWorkspaceForUser')
            .call<Map<String, dynamic>>()
            .timeout(const Duration(seconds: 8));
        final joined = result.data['joined'] as bool? ?? false;
        if (joined) {
          token = await user.getIdTokenResult(true);
          _workspaceId = token.claims?['workspaceId'] as String?;
          _workspaceRole = token.claims?['workspaceRole'] as String?;
        }
      } catch (e) {
        // Non-fatal: if the lookup fails or times out, proceed as if no
        // workspace was found so the user can still create one manually.
        debugPrint('[auth] resolveWorkspaceForUser failed: $e');
      }
    }

    _status = (_workspaceId == null || _workspaceId!.isEmpty)
        ? AuthStatus.signedInNoWorkspace
        : AuthStatus.signedInWithWorkspace;
    notifyListeners();
  }

  Future<bool> _registerSession(User user) async {
    if (!_sessionTrackingAvailable) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionId = _currentOrStoredSessionId(user.uid);
    final sessionRef = _sessionRef(user.uid);
    var conflictDetected = false;

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(sessionRef);
        final data = snap.data();
        final activeSessionId = data?['activeSessionId'] as String?;
        final status = data?['status'] as String?;

        final hasOtherActiveSession = snap.exists &&
            status == 'active' &&
            activeSessionId != null &&
            activeSessionId.isNotEmpty &&
            activeSessionId != sessionId;
        if (hasOtherActiveSession) {
          conflictDetected = true;
          tx.set(sessionRef, {
            'uid': user.uid,
            'email': user.email,
            'status': 'conflict',
            'activeSessionId': null,
            'conflictSessionIds': [activeSessionId, sessionId],
            'conflictDetectedAt': now,
            'lastSeenAt': now,
            'updatedAt': now,
            'metadata': _buildSessionMetadata(user),
          }, SetOptions(merge: true));
          return;
        }

        _sessionId = sessionId;
        _persistSessionId(user.uid, sessionId);
        tx.set(sessionRef, {
          'uid': user.uid,
          'email': user.email,
          'status': 'active',
          'activeSessionId': sessionId,
          'signedInAt': now,
          'lastSeenAt': now,
          'updatedAt': now,
          'metadata': _buildSessionMetadata(user),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      if (_isSessionPermissionError(e)) {
        _disableSessionTracking(
          'Session tracking is disabled until Firestore rules allow '
          'access to userSessions/{uid}.',
        );
        return true;
      }
      rethrow;
    }

    if (conflictDetected) {
      _errorMessage =
          'This account was signed in twice, so both sessions were signed out.';
      notifyListeners();
      await _signOutInternal(
        clearSessionDoc: false,
        clearConflictDoc: true,
      );
      return false;
    }

    _errorMessage = null;
    await _startSessionListener(user);
    _startSessionHeartbeat(user.uid, sessionId);
    return true;
  }

  Future<void> _startSessionListener(User user) async {
    await _sessionSub?.cancel();
    _sessionSub = _sessionRef(user.uid).snapshots().listen(
      (snap) {
        final sessionId = _sessionId;
        if (sessionId == null) return;
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final status = data['status'] as String?;
        final activeSessionId = data['activeSessionId'] as String?;
        final conflictSessionIds =
            (data['conflictSessionIds'] as List?)
                ?.map((v) => v?.toString() ?? '')
                .where((v) => v.isNotEmpty)
                .toSet() ??
            const <String>{};
        final isConflict = status == 'conflict';
        final superseded = status == 'active' &&
            activeSessionId != null &&
            activeSessionId.isNotEmpty &&
            activeSessionId != sessionId;
        final targetedByConflict =
            isConflict && conflictSessionIds.contains(sessionId);
        if (!targetedByConflict && !superseded) return;

        unawaited(
          _forceSignOut(
            'This account was signed in in another window or device. '
            'For safety, both sessions were signed out.',
            clearConflictDoc: targetedByConflict,
          ),
        );
      },
      onError: (Object error) {
        if (error is FirebaseException && _isSessionPermissionError(error)) {
          _disableSessionTracking(
            'Session tracking is disabled until Firestore rules allow '
            'access to userSessions/{uid}.',
          );
          return;
        }
        debugPrint('[auth] session listener failed: $error');
      },
    );
  }

  void _startSessionHeartbeat(String uid, String sessionId) {
    _sessionHeartbeat?.cancel();
    _sessionHeartbeat = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_touchSession(uid, sessionId)),
    );
  }

  Future<void> _touchSession(String uid, String sessionId) async {
    if (!_sessionTrackingAvailable) return;
    final user = _auth.currentUser;
    if (user == null || user.uid != uid || _sessionId != sessionId) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _sessionRef(uid).set({
        'uid': uid,
        'email': user.email,
        'status': 'active',
        'activeSessionId': sessionId,
        'lastSeenAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (e) {
      if (e is FirebaseException && _isSessionPermissionError(e)) {
        _disableSessionTracking(
          'Session tracking is disabled until Firestore rules allow '
          'access to userSessions/{uid}.',
        );
        return;
      }
      debugPrint('[auth] session heartbeat failed: $e');
    }
  }

  Future<void> _forceSignOut(
    String message, {
    bool clearConflictDoc = false,
  }) async {
    if (_handlingForcedSignOut) return;
    _handlingForcedSignOut = true;
    _errorMessage = message;
    notifyListeners();
    try {
      await _signOutInternal(
        clearSessionDoc: false,
        clearConflictDoc: clearConflictDoc,
      );
    } finally {
      _handlingForcedSignOut = false;
    }
  }

  Future<void> _signOutInternal({
    required bool clearSessionDoc,
    bool clearConflictDoc = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    final sessionId = _sessionId;

    _sessionHeartbeat?.cancel();
    _sessionHeartbeat = null;
    await _sessionSub?.cancel();
    _sessionSub = null;

    if (clearSessionDoc && uid != null && sessionId != null) {
      await _clearSessionDoc(uid, sessionId);
    }
    if (clearConflictDoc && uid != null && sessionId != null) {
      await _clearConflictDoc(uid, sessionId);
    }

    if (uid != null) {
      _clearStoredSessionId(uid);
    }
    _sessionId = null;

    await _auth.signOut();
  }

  // On explicit sign-out we *always* reset the session doc — including from
  // a prior 'conflict' state — so the next sign-in can't be misread as a
  // duplicate and trigger the "signed in twice" banner.
  Future<void> _clearSessionDoc(String uid, String sessionId) async {
    final ref = _sessionRef(uid);
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await ref.set({
        'uid': uid,
        'status': 'signedOut',
        'activeSessionId': null,
        'conflictSessionIds': <String>[],
        'signedOutAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[auth] failed to clear session doc: $e');
    }
  }

  Future<void> _clearConflictDoc(String uid, String sessionId) async {
    final ref = _sessionRef(uid);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (!snap.exists || data == null) return;
        if (data['status'] != 'conflict') return;
        final ids = (data['conflictSessionIds'] as List?)
                ?.map((v) => v?.toString() ?? '')
                .where((v) => v.isNotEmpty)
                .toSet() ??
            const <String>{};
        if (!ids.contains(sessionId)) return;
        tx.delete(ref);
      });
    } catch (e) {
      debugPrint('[auth] failed to clear conflict doc: $e');
    }
  }

  void _stopSessionTracking() {
    _sessionHeartbeat?.cancel();
    _sessionHeartbeat = null;
    unawaited(_sessionSub?.cancel());
    _sessionSub = null;
    _sessionId = null;
  }

  DocumentReference<Map<String, dynamic>> _sessionRef(String uid) =>
      _firestore.collection(_sessionCollection).doc(uid);

  String _nextSessionId() {
    _sessionCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_sessionCounter';
  }

  String _currentOrStoredSessionId(String uid) {
    final current = _sessionId;
    if (current != null && current.isNotEmpty) return current;
    if (!kIsWeb) return _nextSessionId();

    final key = _sessionStorageKey(uid);
    final existing = web.window.sessionStorage.getItem(key);
    if (existing != null && existing.isNotEmpty) {
      _sessionId = existing;
      return existing;
    }

    final created = _nextSessionId();
    web.window.sessionStorage.setItem(key, created);
    _sessionId = created;
    return created;
  }

  void _persistSessionId(String uid, String sessionId) {
    if (!kIsWeb) return;
    web.window.sessionStorage.setItem(_sessionStorageKey(uid), sessionId);
  }

  void _clearStoredSessionId(String uid) {
    if (!kIsWeb) return;
    web.window.sessionStorage.removeItem(_sessionStorageKey(uid));
  }

  String _sessionStorageKey(String uid) => 'avokaido.userSession.$uid';

  bool _isSessionPermissionError(FirebaseException e) =>
      e.plugin == 'cloud_firestore' && e.code == 'permission-denied';

  void _disableSessionTracking(String message) {
    _sessionTrackingAvailable = false;
    _sessionHeartbeat?.cancel();
    _sessionHeartbeat = null;
    unawaited(_sessionSub?.cancel());
    _sessionSub = null;
    _sessionId = null;
    _errorMessage = message;
    notifyListeners();
  }

  Map<String, dynamic> _buildSessionMetadata(User user) {
    final providers = user.providerData
        .map((p) => p.providerId)
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    return {
      'email': user.email,
      'displayName': user.displayName,
      'providers': providers,
      'isAnonymous': user.isAnonymous,
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
      'timeZone': DateTime.now().timeZoneName,
      'timeZoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      if (kIsWeb) ...{
        'userAgent': web.window.navigator.userAgent,
        'language': web.window.navigator.language,
        'platform': web.window.navigator.platform,
        'host': web.window.location.host,
        'path': web.window.location.pathname,
      },
    };
  }

  @override
  void dispose() {
    _stopSessionTracking();
    super.dispose();
  }
}
