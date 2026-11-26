import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking_message.dart';

class BookingChatService {
  BookingChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<BookingMessage>> streamMessages(String bookingId) {
    if (bookingId.isEmpty) {
      return Stream.error(ArgumentError.value(bookingId, 'bookingId'));
    }

    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BookingMessage.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> sendMessage({
    required String bookingId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Connectez-vous pour envoyer un message.');
    }

    final message = text.trim();
    if (bookingId.isEmpty || message.isEmpty || message.length > 2000) {
      throw ArgumentError('Le message doit contenir entre 1 et 2 000 caractères.');
    }

    await _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('messages')
        .add({
          'senderId': user.uid,
          'text': message,
          'createdAt': FieldValue.serverTimestamp(),
        });

    // Incrémenter le compteur de messages non lus du destinataire.
    try {
      final bookingSnap =
          await _firestore.collection('bookings').doc(bookingId).get();
      final booking = bookingSnap.data();
      if (booking != null) {
        final clientId = booking['clientId']?.toString();
        final proId = booking['proId']?.toString();
        String? field;
        if (user.uid == clientId) field = 'unreadPro';
        else if (user.uid == proId) field = 'unreadClient';
        if (field != null) {
          await _firestore.collection('bookings').doc(bookingId).update({
            field: FieldValue.increment(1),
          });
        }
      }
    } catch (_) {}
  }
}
