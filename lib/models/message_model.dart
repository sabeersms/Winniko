import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isOrganizer;
  final bool isSystem;
  final String? imageUrl;
  final bool isPinned;
  final List<String> readBy;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isOrganizer,
    this.isSystem = false,
    this.imageUrl,
    this.isPinned = false,
    this.readBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isOrganizer': isOrganizer,
      'isSystem': isSystem,
      'imageUrl': imageUrl,
      'isPinned': isPinned,
      'readBy': readBy,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MessageModel(
      id: documentId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isOrganizer: map['isOrganizer'] ?? false,
      isSystem: map['isSystem'] ?? false,
      imageUrl: map['imageUrl'],
      isPinned: map['isPinned'] ?? false,
      readBy: List<String>.from(map['readBy'] ?? []),
    );
  }

  factory MessageModel.fromSnapshot(DocumentSnapshot snapshot) {
    return MessageModel.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }
}
