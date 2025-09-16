import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'message_content.dart';
import 'status_icons.dart';
import 'reply_widgets.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDelivered;
  final bool isSeen;
  final void Function(Map<String, dynamic> message)? onEdit;
  final void Function(Map<String, dynamic> message)? onDelete;
  final void Function(Map<String, dynamic> message)? onReply;
  final void Function(Map<String, dynamic> message, bool isMe)? onShowOptions;
  final Map<String, dynamic>? Function(String id)? getMessageById;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDelivered,
    required this.isSeen,
    this.onEdit,
    this.onDelete,
    this.onReply,
    this.onShowOptions,
    this.getMessageById,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => onShowOptions?.call(message, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            gradient: isMe
                ? const LinearGradient(
                    colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isMe ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message['reply_to_id'] != null && getMessageById != null)
                ReplyBubblePreview(
                  repliedMessage: getMessageById!(message['reply_to_id']),
                  isMe: isMe,
                ),
              MessageContent(message: message, isMe: isMe),
              const SizedBox(height: 4),
              Text(
                message['created_at'] != null
                    ? DateFormat(
                        'HH:mm',
                      ).format(DateTime.parse(message['created_at']).toLocal())
                    : '',
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.black38,
                  fontSize: 11,
                ),
              ),
              if (isMe)
                MessageStatusIcons(
                  isDelivered: isDelivered,
                  isSeen: isSeen,
                  color: isMe ? Colors.white70 : Colors.black38,
                ),
            ],
          ),
        ),
      ),
    );
  }
}