import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<UserCredential> signUpWithEmail(String email, String password);
  Future<UserCredential> signInWithGoogle();
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<void> syncWithBackend();
  
  Future<void> reAuthWithGoogle();
  Future<void> deleteAccount();

  // Token management for persistence
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> deleteToken();
}







