import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sampada/data/repositories/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _repository;
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  AuthProvider({required AuthRepository repository}) : _repository = repository {
    _init();
  }

  Future<void> _init() async {
    // Check initial current user immediately
    _user = _repository.currentUser;
    
    _repository.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        try {
          // Only hit the backend if we have no stored JWT.
          // If tokens exist, ApiClient's interceptor will refresh them as needed.
          final storedToken = await _repository.getToken();
          if (storedToken == null || storedToken.isEmpty) {
            await _repository.syncWithBackend();
          }
        } catch (e) {
          debugPrint('Error syncing with backend on init: $e');
        }
      }
      _isInitialized = true;
      notifyListeners();
    });

    // Fallback safety: if Firebase doesn't emit a user within 2 seconds, 
    // mark as initialized anyway to prevent splash lock.
    Future.delayed(const Duration(seconds: 10), () {
      if (!_isInitialized) {
        _isInitialized = true;
        notifyListeners();
      }
    });
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isEmailVerified => _user?.emailVerified ?? false;
  bool get isGoogleUser => _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  Future<void> sendEmailVerification() async {
    if (_user != null && !_user!.emailVerified) {
      await _user!.sendEmailVerification();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.sendPasswordResetEmail(email);
    } catch (e) {
      _error = _handleAuthError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _repository.signInWithEmail(email, password);
      final user = credential.user;

      if (user != null && !user.emailVerified) {
        // Sign out immediately if email is not verified
        await _repository.signOut();
        _user = null;
        _error = 'Please verify your email before logging in. Check your inbox for the verification link.';
        return;
      }

      _user = user;
      
      final token = await _user?.getIdToken();
      if (token != null) {
        await _repository.saveToken(token);
      }
      
      // Navigate to profile is handled in the UI
    } catch (e) {
      _error = _handleAuthError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password, {String? fullName}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _repository.signUpWithEmail(email, password);
      _user = credential.user;
      
      final token = await _user?.getIdToken();
      if (token != null) {
        await _repository.saveToken(token);
      }
      
      if (fullName != null && _user != null) {
        await _user!.updateDisplayName(fullName);
        await _user!.reload();
        _user = _repository.currentUser;
      }

      // Send verification email
      await sendEmailVerification();
    } catch (e) {
      _error = _handleAuthError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _repository.signInWithGoogle();
      _user = credential.user;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      _error = msg.contains('cancel') ? null : e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({String? displayName, String? email, String? password}) async {
    if (_user == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Starting profile update. Re-authenticating...');
      
      // Re-auth only needed for email/password users
      if (!isGoogleUser) {
        if (password == null || password.isEmpty) {
          throw FirebaseAuthException(
            code: 'wrong-password',
            message: 'Password is required to confirm changes.',
          );
        }
        final credential = EmailAuthProvider.credential(
          email: _user!.email!,
          password: password,
        );
        await _user!.reauthenticateWithCredential(credential);
      }

      // 2. Only if re-auth is successful, perform updates
      if (displayName != null && displayName != _user!.displayName) {
        debugPrint('Updating display name to: $displayName');
        await _user!.updateDisplayName(displayName);
      }

      if (email != null && email != _user!.email) {
        debugPrint('Updating email to: $email');
        await _user!.verifyBeforeUpdateEmail(email);
        _error = 'A verification email has been sent to $email. Please verify it to complete the change.';
      }

      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;
      debugPrint('Profile update process completed successfully.');
      notifyListeners();
    } catch (e) {
      debugPrint('Profile update failed: $e');
      _error = _handleAuthError(e);
      notifyListeners();
      rethrow; // Ensure UI can catch this
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'The account already exists for that email.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'invalid-credential':
          return 'The password you entered is incorrect. Please try again.';
        default:
          return 'Authentication failed: ${e.message}';
      }
    }
    return e.toString();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.signOut();
      _user = null;
    } catch (e) {
      _error = 'Logout failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount({String? password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (isGoogleUser) {
        await _repository.reAuthWithGoogle();
      } else {
        final credential = EmailAuthProvider.credential(
          email: _user!.email!,
          password: password!,
        );
        await _user!.reauthenticateWithCredential(credential);
      }
      await _repository.deleteAccount();
      _user = null;
    } catch (e) {
      _error = _handleAuthError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}







