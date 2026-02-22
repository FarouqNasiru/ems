import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign Up
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;

      if (user != null) {
        // Update Firebase Auth Profile
        await user.updateDisplayName(displayName);
        await user.reload();

        // Create User Document in Firestore (Optional but good for extra data)
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'displayName': displayName,
          'photoURL': null,
          'role': 'employee', // Default role for new users
          'createdAt': FieldValue.serverTimestamp(),
        });

        return _auth.currentUser; // Return reloaded user
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  // Get User Role
  Future<String> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'employee';

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['role'] ?? 'employee';
      }
    } catch (e) {
      print("Error fetching user role: $e");
    }
    return 'employee';
  }

  // Ensure User Document Exists (Fix for existing users)
  Future<void> ensureUserDocument() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'User',
        'photoURL': user.photoURL,
        'role': 'employee', // Default to employee
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Sign In
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
