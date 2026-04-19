import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;

  Future<String> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential credential)? onAutoVerify,
  }) async {
    final completer = Completer<String>();

    try {
      // Configure Firebase Auth settings for Android
      if (Platform.isAndroid) {
        await _auth.setSettings(
          appVerificationDisabledForTesting: kDebugMode,
          forceRecaptchaFlow: false, // Disable web reCAPTCHA flow
        );
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken, // Use previous token for resending
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (Android only)
          // This happens when SMS is automatically read
          if (onAutoVerify != null) {
            onAutoVerify(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = 'Verification failed';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Please try again later';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'SMS quota exceeded';
          } else if (e.code == 'network-request-failed') {
            errorMessage = 'Network error. Please check your connection';
          }
          debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
          onError(errorMessage);
          if (!completer.isCompleted) {
            completer.completeError(errorMessage);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken; // Save for potential resend
          onCodeSent(verificationId);
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Timeout for automatic SMS code retrieval
          _verificationId = verificationId;
        },
      );

      return await completer.future;
    } catch (e) {
      debugPrint('Phone verification error: $e');
      onError(e.toString());
      rethrow;
    }
  }

  Future<String> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get ID token');
      }

      return idToken;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw Exception('Invalid verification code');
      } else if (e.code == 'session-expired') {
        throw Exception('Code expired. Please request a new code');
      }
      throw Exception('Verification failed: ${e.message}');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
