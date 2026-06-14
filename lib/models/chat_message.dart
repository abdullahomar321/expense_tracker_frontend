import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.timestamp,
    required this.status,
    this.imageBase64,
  });

  final String id;
  final String senderId;
  final String text;
  final String type; // "text" | "image"
  final String? imageBase64;
  final DateTime timestamp;
  final String status; // "sent" | "read"

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      imageBase64: data['imageBase64'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'sent',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
    };
  }
}
