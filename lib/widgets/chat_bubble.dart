import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isUser
        ? const Color(0xFF14532D)
        : (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white);

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(20),
              topEnd: const Radius.circular(20),
              bottomStart: Radius.circular(isUser ? 20 : 5),
              bottomEnd: Radius.circular(isUser ? 5 : 20),
            ),
            border: isUser
                ? null
                : Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.text,
            textDirection: Directionality.of(context),
            style: TextStyle(
              color: isUser
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : colorScheme.onSurface),
              height: 1.4,
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }
}
