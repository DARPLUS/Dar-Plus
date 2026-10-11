import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class InAppNotification {
  final String id;
  final String title;
  final String message;
  final ProApplication proApplication;
  final DateTime timestamp;
  bool isRead;

  InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.proApplication,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<InAppNotification> _notifications = [];
  final _notificationStreamController =
      StreamController<InAppNotification>.broadcast();

  Stream<InAppNotification> get onNewNotification =>
      _notificationStreamController.stream;

  List<InAppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
  }

  /// Déclenché quand un professionnel soumet son inscription
  void notifyAdminNewProApplication(ProApplication app) {
    final notification = InAppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Nouvelle demande Partenaire !',
      message:
          '${app.fullName} souhaite rejoindre DAR PLUS pour le métier : ${app.serviceType}.',
      proApplication: app,
      timestamp: DateTime.now(),
    );

    _notifications.insert(0, notification);
    _notificationStreamController.add(notification);
  }

  /// Affiche une bannière de notification cliquable en haut de l'écran
  static void showClickableAdminBanner(
    BuildContext context,
    InAppNotification notification, {
    required VoidCallback onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            tween: Tween(begin: -50, end: 0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: InkWell(
              onTap: () {
                entry.remove();
                onTap();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C5050),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE8834F),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8834F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                notification.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Cliquer pour voir',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notification.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Auto dismiss après 6 secondes si non cliqué
    Future.delayed(const Duration(seconds: 6), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}
