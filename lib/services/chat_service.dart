import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/chat_message.dart';
import 'package:expense_tracker/models/chat_room.dart';

/// All Firestore operations for the 1:1 chat feature.
class ChatService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference get _chats => _db.collection('chats');
  static CollectionReference get _users => _db.collection('users');

  // ---------------------------------------------------------------------------
  // Chat ID helpers
  // ---------------------------------------------------------------------------

  /// Computes the canonical chat ID by sorting the two UIDs alphabetically.
  static String chatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ---------------------------------------------------------------------------
  // Chat creation / retrieval
  // ---------------------------------------------------------------------------

  /// Returns the chat document reference, creating the chat document if it
  /// does not yet exist.
  static Future<DocumentReference> getOrCreateChat(
    String uid1,
    String uid2,
  ) async {
    final id = chatId(uid1, uid2);
    final ref = _chats.doc(id);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'participants': [uid1, uid2],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'unreadCount': {uid1: 0, uid2: 0},
      });
    }

    return ref;
  }

  // ---------------------------------------------------------------------------
  // Sending messages
  // ---------------------------------------------------------------------------

  /// Sends a text message as an atomic batch write.
  static Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String recipientId,
    required String text,
  }) async {
    final chatRef = _chats.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final batch = _db.batch();

    // 1. New message document
    batch.set(messageRef, {
      'senderId': senderId,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
    });

    // 2. Update chat doc: lastMessage + increment recipient unread
    batch.update(chatRef, {
      'lastMessage': {
        'text': text,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      },
      'unreadCount.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Sends an image (base64) message as an atomic batch write.
  static Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required String recipientId,
    required String imageBase64,
  }) async {
    final chatRef = _chats.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final batch = _db.batch();

    // 1. New message document
    batch.set(messageRef, {
      'senderId': senderId,
      'text': '',
      'type': 'image',
      'imageBase64': imageBase64,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
    });

    // 2. Update chat doc: lastMessage shows placeholder text
    batch.update(chatRef, {
      'lastMessage': {
        'text': '📷 Photo',
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
      },
      'unreadCount.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Reading messages (paginated real-time stream)
  // ---------------------------------------------------------------------------

  /// Returns a real-time stream of the latest [limit] messages in a chat.
  /// Pass [startAfterDoc] to paginate to older messages.
  static Stream<List<ChatMessage>> getMessagesStream(
    String chatId, {
    int limit = 20,
    DocumentSnapshot? startAfterDoc,
  }) {
    Query query = _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    return query.snapshots().map(
          (snap) => snap.docs.map(ChatMessage.fromDoc).toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Chat list stream
  // ---------------------------------------------------------------------------

  /// Streams the list of chat rooms for a user, ordered by last message time.
  static Stream<List<ChatRoom>> getChatListStream(String userId) {
    return _chats
        .where('participants', arrayContains: userId)
        .orderBy('lastMessage.timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatRoom.fromDoc).toList());
  }

  // ---------------------------------------------------------------------------
  // Read receipts
  // ---------------------------------------------------------------------------

  /// Resets the unread count for [userId] and marks all their unread messages
  /// as "read" via batch update (up to 500 at a time).
  static Future<void> markChatRead({
    required String chatId,
    required String userId,
  }) async {
    final chatRef = _chats.doc(chatId);

    // Reset unread counter
    await chatRef.update({'unreadCount.$userId': 0});

    // Mark unread messages as read
    final unreadMessages = await chatRef
        .collection('messages')
        .where('status', isEqualTo: 'sent')
        .where('senderId', isNotEqualTo: userId)
        .limit(100)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // User profile helpers
  // ---------------------------------------------------------------------------

  /// Fetches a user profile from Firestore users/{userId}.
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    final snap = await _users.doc(userId).get();
    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>?;
  }

  /// Fetches multiple user profiles at once (in parallel).
  static Future<Map<String, Map<String, dynamic>>> getUserProfiles(
    List<String> userIds,
  ) async {
    final futures = userIds.map((id) async {
      final profile = await getUserProfile(id);
      return MapEntry(id, profile ?? <String, dynamic>{});
    });
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }
}
