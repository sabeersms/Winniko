import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id; // participantId
  final String competitionId;
  final String participantId;
  final String participantName;
  final String participantAvatar; // Optional
  final String lastMessage;
  final DateTime lastMessageTime;
  final int participantUnreadCount;
  final int organizerUnreadCount;

  ChatModel({
    required this.id,
    required this.competitionId,
    required this.participantId,
    required this.participantName,
    this.participantAvatar = '',
    required this.lastMessage,
    required this.lastMessageTime,
    this.participantUnreadCount = 0,
    this.organizerUnreadCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'competitionId': competitionId,
      'participantId': participantId,
      'participantName': participantName,
      'participantAvatar': participantAvatar,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'participantUnreadCount': participantUnreadCount,
      'organizerUnreadCount': organizerUnreadCount,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ChatModel(
      id: documentId,
      competitionId: map['competitionId'] ?? '',
      participantId: map['participantId'] ?? '',
      participantName: map['participantName'] ?? 'Unknown',
      participantAvatar: map['participantAvatar'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp).toDate(),
      participantUnreadCount: map['participantUnreadCount'] ?? 0,
      organizerUnreadCount: map['organizerUnreadCount'] ?? 0,
    );
  }

  factory ChatModel.fromSnapshot(DocumentSnapshot snapshot) {
    return ChatModel.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }
}
