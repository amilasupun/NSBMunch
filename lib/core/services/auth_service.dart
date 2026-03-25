import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_strings.dart';

class AuthService {
  // Firebase instances
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Admin - hardcoded check
      if (email.trim() == AppStrings.adminEmail &&
          password == AppStrings.adminPassword) {
        return {'success': true, 'role': AppStrings.admin};
      }

      // Normal Firebase login
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Get user data from Firestore
      final doc = await _db.collection('users').doc(result.user!.uid).get();
      final data = doc.data() ?? {};

      final String role = data['role'] ?? AppStrings.student;
      final String status = data['status'] ?? 'active';

      // Block pending vendors
      if (role == AppStrings.vendor && status == 'pending') {
        await _auth.signOut();
        return {'success': false, 'error': AppStrings.vendorPending};
      }

      // Rejected vendor
      if (role == AppStrings.vendor && status == 'rejected') {
        await _auth.signOut();
        return {'success': false, 'error': AppStrings.vendorRejected};
      }

      return {'success': true, 'role': role};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _errorMsg(e.code)};
    } catch (_) {
      return {'success': false, 'error': 'Something went wrong. Try again.'};
    }
  }

  // register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String shopName = '',
    String shopId = '',
  }) async {
    try {
      if (role == AppStrings.vendor) {
        final taken = await _isShopIdTaken(shopId);
        if (taken) {
          return {
            'success': false,
            'error': 'Shop ID "$shopId" is already taken.',
          };
        }
      }
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = result.user!.uid;
      final String status = role == AppStrings.vendor ? 'pending' : 'active';
      final Map<String, dynamic> userData = {
        'uid': uid,
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (role == AppStrings.vendor) {
        userData['shopName'] = shopName.trim();
        userData['shopId'] = shopId.trim();
      }

      await _db.collection('users').doc(uid).set(userData);

      return {'success': true, 'role': role, 'status': status};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _errorMsg(e.code)};
    } catch (_) {
      return {'success': false, 'error': 'Registration failed. Try again.'};
    }
  }

  // password reset
  Future<Map<String, dynamic>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _errorMsg(e.code)};
    } catch (_) {
      return {'success': false, 'error': 'Could not send reset email.'};
    }
  }

  // delete rejected vendor account
  Future<Map<String, dynamic>> deleteRejectedAccount(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = result.user!.uid;
      await _db.collection('users').doc(uid).delete();
      await result.user!.delete();

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _errorMsg(e.code)};
    } catch (_) {
      return {'success': false, 'error': 'Could not delete account.'};
    }
  }

  Future<String?> getCurrentUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      if (user.email == AppStrings.adminEmail) return AppStrings.admin;

      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final String role = data['role'] ?? AppStrings.student;
      final String status = data['status'] ?? 'active';

      if (role == AppStrings.vendor &&
          (status == 'pending' || status == 'rejected')) {
        await _auth.signOut();
        return null;
      }

      return role;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  // logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // helpers
  Future<bool> _isShopIdTaken(String shopId) async {
    final query = await _db
        .collection('users')
        .where('shopId', isEqualTo: shopId.trim())
        .get();
    return query.docs.isNotEmpty;
  }

  String _errorMsg(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Wrong password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'requires-recent-login':
        return 'Please login again to continue.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
