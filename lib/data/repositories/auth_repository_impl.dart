import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:sampada/core/data/datasources/secure_token_storage.dart';
import 'package:sampada/data/repositories/auth_repository.dart';
import 'package:sampada/data/datasources/remote/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth? _firebaseAuth;
  final AuthRemoteDataSource? _remoteDataSource;
  final SecureTokenStorage _tokenStorage;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    AuthRemoteDataSource? remoteDataSource,
    SecureTokenStorage? tokenStorage,
  })  : _firebaseAuth = firebaseAuth,
        _remoteDataSource = remoteDataSource,
        _tokenStorage = tokenStorage ?? SecureTokenStorage();

  FirebaseAuth get auth {
    if (_firebaseAuth == null) {
      throw Exception('Firebase Auth not initialized. Check your configuration.');
    }
    return _firebaseAuth!;
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _googleSignIn.initialize(
        clientId: '813832542964-8c4gut4u9it22dun1lacq0uvk88ak41k.apps.googleusercontent.com',
      );
      _isGoogleSignInInitialized = true;
    }
  }

  @override
  Future<void> syncWithBackend() async {
    final user = auth.currentUser;
    if (user != null && _remoteDataSource != null) {
      final idToken = await user.getIdToken();
      if (idToken != null) {
        final response = await _remoteDataSource!.syncUser(idToken);
        
        // Save the JWTs returned by our backend
        if (response.containsKey('access') && response.containsKey('refresh')) {
          await _tokenStorage.saveTokens(
            accessToken: response['access'],
            refreshToken: response['refresh'],
          );
        }
      }
    }
  }

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await syncWithBackend();
    return credential;
  }

  @override
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await syncWithBackend();
    return credential;
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
    if (googleUser == null) {
      throw Exception('Google Sign-In was cancelled by the user.');
    }

    final GoogleSignInClientAuthorization authz = 
        await googleUser.authorizationClient.authorizeScopes([]);
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: authz.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await auth.signInWithCredential(credential);
    await syncWithBackend();
    return userCredential;
  }

  @override
  Future<void> signOut() async {
    // Notify backend first (clears FCM token, blacklists refresh token)
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      await _remoteDataSource?.logout(refreshToken);
    } catch (e) {
      debugPrint('Backend logout failed (continuing): $e');
    }

    try {
      await _tokenStorage.clearTokens();
    } catch (e) {
      debugPrint('Error clearing tokens during logout: $e');
    }

    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error signing out of Google: $e');
    }

    try {
      await _firebaseAuth?.signOut();
    } catch (e) {
      debugPrint('Error signing out of Firebase: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  @override
  Stream<User?> get authStateChanges => _firebaseAuth?.authStateChanges() ?? Stream.value(null);

  @override
  User? get currentUser => _firebaseAuth?.currentUser;

  @override
  Future<void> saveToken(String token) async {
    await _tokenStorage.saveTokens(accessToken: token, refreshToken: '');
  }

  @override
  Future<String?> getToken() async {
    return await _tokenStorage.getAccessToken();
  }

  @override
  Future<void> deleteToken() async {
    await _tokenStorage.clearTokens();
  }
}







