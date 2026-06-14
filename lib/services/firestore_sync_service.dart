import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';

/// Syncs the current Laravel user's profile to Firestore users/{userId}.
/// This keeps Firestore in sync with Laravel as the source of truth.
/// Called fire-and-forget on every login and session restore.
class FirestoreSyncService {
  static final _firestore = FirebaseFirestore.instance;

  /// Syncs user data to Firestore. Call after login or session restore.
  /// [userId] — Laravel numeric ID (as string)
  static Future<void> syncUser({
    required String userId,
    required String displayName,
    required String email,
    String photoUrl = '',
  }) async {
    if (userId.isEmpty) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Persist userId locally for cold-start access
      await SecureTokenStorage.saveUserId(userId);
    } catch (e) {
      // Non-fatal: chat sync failure should not break the app
    }
  }

  /// Clears the locally stored userId on logout.
  static Future<void> clearLocalUserId() async {
    await SecureTokenStorage.deleteUserId();
  }
}
