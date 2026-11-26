import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({
    super.key,
    required this.controller,
    required this.formKey,
    required this.isSending,
    required this.onSend,
    this.onMore,
  });

  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final bool isSending;
  final ValueChanged<String> onSend;
  final VoidCallback? onMore;

  void _submit() {
    final text = controller.text.trim();
    if (isSending || !(formKey.currentState?.validate() ?? false)) return;
    onSend(text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F4),
          border: Border(top: const BorderSide(color: Color(0xFFE5DDD7))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: IconButton.filledTonal(
                tooltip: 'ai_more_actions'.tr(),
                onPressed: isSending ? null : onMore,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D7772),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.add_rounded, size: 24),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'ai_message_required'.tr()
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'ai_input_hint'.tr(),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFE5DDD7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFE5DDD7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: Color(0xFF0D7772),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 42,
              height: 42,
              child: IconButton.filled(
                tooltip: 'ai_send'.tr(),
                onPressed: isSending ? null : _submit,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF9CCFCB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB7C2C1),
                ),
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
