import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.participants,
    required this.unreadCount,
    this.createdAt,
    this.lastMessage,
  });

  final String id; // sorted "uid1_uid2"
  final List<String> participants;
  final DateTime? createdAt;
  final Map<String, dynamic>? lastMessage;
  final Map<String, int> unreadCount;

  factory ChatRoom.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final rawParticipants = data['participants'] as List<dynamic>? ?? [];
    final participants = rawParticipants.map((e) => e.toString()).toList();

    final rawUnread = data['unreadCount'] as Map<String, dynamic>? ?? {};
    final unreadCount = rawUnread.map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );

    return ChatRoom(
      id: doc.id,
      participants: participants,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastMessage: data['lastMessage'] as Map<String, dynamic>?,
      unreadCount: unreadCount,
    );
  }

  /// Returns the unread count for a specific user.
  int unreadFor(String userId) => unreadCount[userId] ?? 0;

  /// Returns the other participant's UID given the current user's UID.
  String otherUserId(String currentUserId) {
    return participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '',
    );
  }
}
