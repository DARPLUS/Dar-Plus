import 'package:cloud_firestore/cloud_firestore.dart';

class BookingMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  const BookingMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory BookingMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['createdAt'];
    return BookingMessage(
      id: document.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}
