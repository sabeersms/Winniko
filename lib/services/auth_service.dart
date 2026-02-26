import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Master Admin Check
  bool get isMasterAdmin {
    final email = _auth.currentUser?.email;
    if (email == null) return false;
    const masterEmails = [
      'sabeersms@gmail.com',
      'teamwinniko@gmail.com',
      '2mobilecampus@gmail.com',
    ];
    return masterEmails.contains(email.toLowerCase());
  }

  /// Registers the current user's UID in the Firestore 'admins' collection
  /// if they are a master admin. This is needed so Firestore security rules
  /// can identify phone-authenticated admins by UID (not just by token email).
  Future<void> registerAdminUidIfNeeded() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check app-side admin status
      final email = user.email ?? '';
      const masterEmails = [
        'sabeersms@gmail.com',
        'teamwinniko@gmail.com',
        '2mobilecampus@gmail.com',
      ];

      if (masterEmails.contains(email.toLowerCase())) {
        // Write UID to admins collection so Firestore rules can check it
        await _firestore.collection('admins').doc(user.uid).set({
          'email': email,
          'registeredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ Admin UID registered: ${user.uid}');
      }
    } catch (e) {
      // Non-fatal: log but don't block login
      debugPrint('⚠️ Could not register admin UID: $e');
    }
  }

  // Stream of auth state changes
  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  // Check if current user email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Reload current user to refresh emailVerified status
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to refresh user status: ${e.toString()}');
    }
  }

  // Send verification email
  Future<void> sendEmailVerification() async {
    try {
      debugPrint(
        'Attempting to send verification email to: ${_auth.currentUser?.email}',
      );
      await _auth.currentUser?.sendEmailVerification();
      debugPrint('Verification email sent successfully.');
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      throw Exception('Failed to send verification email: ${e.toString()}');
    }
  }

  // Helper to generate a consistent fake email from a phone number
  String _getEmailFromPhone(String phoneNumber) {
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    return "$cleanPhone@winniko.com";
  }

  // --- Email/Password Authentication ---

  // Sign up with Email and Password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already registered.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is not valid.');
      } else if (e.code == 'weak-password') {
        throw Exception('The password is too weak.');
      }
      throw Exception(e.message ?? 'Signup failed');
    } catch (e) {
      throw Exception('Signup failed: ${e.toString()}');
    }
  }

  // Sign in with Email and Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw Exception('Incorrect email or password.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many failed attempts. Please try again later.');
      }
      throw Exception(e.message ?? 'Login failed. Please try again.');
    } catch (e) {
      throw Exception('Login failed. Please check your connection.');
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Firebase Auth "user-not-found" error behavior depends on the
      // "Email Enumeration Protection" setting in the Firebase Console.
      // If protection is ON, this error is NOT thrown (method returns success).
      // If protection is OFF, this error IS thrown.
      if (e.code == 'user-not-found') {
        throw Exception('No account found for this email.');
      }
      throw Exception(e.message ?? 'Failed to send reset email');
    } catch (e) {
      throw Exception('Failed to send reset email: ${e.toString()}');
    }
  }

  // --- Phone/OTP Authentication (Legacy/Alternative) ---
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(String error) verificationFailed,
    Function(PhoneAuthCredential credential)? verificationCompleted,
    Function(String verificationId)? codeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (verificationCompleted != null) {
            verificationCompleted(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String message;
          if (e.code == 'invalid-phone-number') {
            message = 'The phone number entered is invalid.';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please try again tomorrow.';
          } else {
            message = e.message ?? 'Verification failed';
          }
          verificationFailed(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          codeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (codeAutoRetrievalTimeout != null) {
            codeAutoRetrievalTimeout(verificationId);
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      verificationFailed(e.toString());
    }
  }

  // Verify OTP (Generic)
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Just sign in with phone credential first
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw Exception('The OTP you entered is incorrect. Please try again.');
      } else if (e.code == 'expired-verification-code') {
        throw Exception('The OTP has expired. Please request a new one.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many attempts. Please try again later.');
      }
      throw Exception(e.message ?? 'Verification failed');
    } catch (e) {
      throw Exception('Invalid OTP: ${e.toString()}');
    }
  }

  // Create Password for Phone Account (Link Email/Password)
  Future<void> registerPasswordForPhone({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Create a fake email based on phone number
        String email = _getEmailFromPhone(phoneNumber);

        // Link Email/Password credential
        AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );

        // Use linkWithCredential instead of updateEmail/updatePassword to ensure provider linkage
        await user.linkWithCredential(credential);
      }
    } catch (e) {
      throw Exception('Failed to set password: ${e.toString()}');
    }
  }

  // Login with Phone and Password
  Future<UserCredential> signInWithPhonePassword(
    String phoneNumber,
    String password,
  ) async {
    try {
      String email = _getEmailFromPhone(phoneNumber);
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw Exception('Incorrect phone number or password');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect phone number or password');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many attempts. Please try again later.');
      }
      throw Exception(e.message ?? 'Login failed');
    } catch (e) {
      throw Exception('Login failed. Please check your connection.');
    }
  }

  // Check if user profile exists
  Future<bool> userProfileExists(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get user profile
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        UserModel user = UserModel.fromSnapshot(doc);
        if (userId == currentUserId) {
          _currentUserModel = user;
          notifyListeners();
        }
        return user;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // Refresh current user model
  Future<void> syncUserProfile() async {
    final uid = currentUserId;
    if (uid != null) {
      await getUserProfile(uid);
    }
  }

  // Create user profile
  Future<void> createUserProfile(UserModel user) async {
    try {
      // 1. Create main profile
      await _firestore.collection('users').doc(user.id).set(user.toMap());

      // 2. Update email index for forgot password checks
      String cleanEmail = user.email.trim().toLowerCase();
      if (cleanEmail.isNotEmpty) {
        await _firestore.collection('email_indices').doc(cleanEmail).set({
          'uid': user.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Update phone index for 100% reliable existence check
      String cleanPhone = user.phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isNotEmpty) {
        await _firestore.collection('phone_indices').doc(cleanPhone).set({
          'uid': user.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to create user profile: ${e.toString()}');
    }
  }

  // Check if phone/email is already registered (Secure Index + Auth Trick)
  Future<bool> checkUserExists(String phoneNumber, [String? email]) async {
    try {
      debugPrint('--- DEEP CHECK: Phone=$phoneNumber, Email=$email ---');
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

      // 1. Phone Index Check
      if (cleanPhone.isNotEmpty) {
        try {
          final indexDoc = await _firestore
              .collection('phone_indices')
              .doc(cleanPhone)
              .get();
          if (indexDoc.exists) {
            final uid = indexDoc.data()?['uid'] as String?;
            if (uid != null) {
              // Verify user document actually exists
              final userDoc = await _firestore
                  .collection('users')
                  .doc(uid)
                  .get();
              if (userDoc.exists) {
                debugPrint('SUCCESS: Found valid user in phone_indices');
                return true;
              } else {
                debugPrint('INFO: Found zombie phone index (User doc missing)');
              }
            }
          }
        } catch (e) {
          debugPrint('Phone Index check failed: $e');
        }
      }

      // 2. Email Index Check (If provided)
      if (email != null && email.isNotEmpty) {
        try {
          final emailDoc = await _firestore
              .collection('email_indices')
              .doc(email.trim().toLowerCase())
              .get();
          if (emailDoc.exists) {
            final uid = emailDoc.data()?['uid'] as String?;
            if (uid != null) {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(uid)
                  .get();
              if (userDoc.exists) {
                debugPrint('SUCCESS: Found valid user in email_indices');
                return true;
              } else {
                debugPrint('INFO: Found zombie email index (User doc missing)');
              }
            }
          }
        } catch (e) {
          debugPrint('Email Index check failed: $e');
        }
      }

      // 3. Secondary Check: Auth Enumeration
      // Try multiple formats to catch legacy users
      List<String> formatsToTry = [
        _getEmailFromPhone(phoneNumber), // Optimized (Digits only)
        "${phoneNumber.replaceAll('+', '')}@winniko.com", // Legacy (Might have spaces)
      ];

      if (email != null) formatsToTry.add(email); // Check actual email too

      for (String emailToCheck in formatsToTry) {
        debugPrint('Checking Auth for: $emailToCheck');

        // Note: fetchSignInMethodsForEmail was deprecated and removed.
        // We now rely on the sign-in attempt below as a robust check.

        // 4. Tertiary Check: Sign-in attempt (Fallback)
        try {
          await _auth.signInWithEmailAndPassword(
            email: emailToCheck,
            password: 'dummy_random_password_check',
          );
          debugPrint('SUCCESS: Logged in (should not happen with dummy pass)');
          return true;
        } on FirebaseAuthException catch (e) {
          debugPrint('Auth Code for $emailToCheck: ${e.code}');
          if (e.code == 'wrong-password' || e.code == 'too-many-requests') {
            debugPrint('SUCCESS: Confirmed exists via ${e.code}');
            return true;
          }
        }
      }

      debugPrint('RESULT: User does not exist');
      return false;
    } catch (e) {
      debugPrint('CRITICAL: Existence check crashed: $e');
      return false;
    }
  }

  // Check if phone number is already registered (Firestore search, requires auth)
  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking phone registration: $e');
      return false;
    }
  }

  // Update password for signed-in user
  Future<void> updateAccountPassword(String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Update password (requires recent sign-in, which OTP provides)
      await user.updatePassword(newPassword);
    } catch (e) {
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user profile: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      String? userId = currentUserId;
      if (userId != null) {
        // 1. Get user profile to find phone/email keys
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final email = userData['email'] as String?;
          final phone = userData['phone'] as String?;

          // 2. Delete Email Index
          if (email != null && email.trim().isNotEmpty) {
            final cleanEmail = email.trim().toLowerCase();
            await _firestore
                .collection('email_indices')
                .doc(cleanEmail)
                .delete();
          }

          // 3. Delete Phone Index
          if (phone != null && phone.trim().isNotEmpty) {
            final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
            if (cleanPhone.isNotEmpty) {
              await _firestore
                  .collection('phone_indices')
                  .doc(cleanPhone)
                  .delete();
            }
          }
        }

        // 4. Delete user data from Firestore
        await _firestore.collection('users').doc(userId).delete();

        // 5. Delete Firebase Auth account
        await _auth.currentUser?.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }
}
