import 'package:flutter/material.dart';

class ReplyBubblePreview extends StatelessWidget {
  final Map<String, dynamic>? repliedMessage;
  final bool isMe;

  const ReplyBubblePreview({
    super.key,
    required this.repliedMessage,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (repliedMessage == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isMe ? Colors.white24 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Message unavailable',
          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
        ),
      );
    }
    final content = repliedMessage!['content'] ?? '';
    final type = repliedMessage!['type'] ?? 'text';
    final preview = type == 'text'
        ? content
        : type == 'image'
        ? '📷 Photo'
        : type == 'voice'
        ? '🎤 Voice message'
        : type == 'video'
        ? '🎬 Video'
        : type == 'music'
        ? '🎵 Music'
        : '📎 Attachment';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMe ? Colors.white24 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? const Color(0xFF46C2CB) : const Color(0xFF6D5BFF),
            width: 4,
          ),
        ),
      ),
      child: Text(
        preview.length > 40 ? preview.substring(0, 40) + '...' : preview,
        style: TextStyle(
          fontSize: 13,
          color: isMe ? Colors.white : Colors.black87,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onCancel;
  final Map<String, dynamic>? Function(String id) getMessageById;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.onCancel,
    required this.getMessageById,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content'] ?? '';
    final type = message['type'] ?? 'text';
    final preview = type == 'text'
        ? content
        : type == 'image'
        ? '📷 Photo'
        : type == 'voice'
        ? '🎤 Voice message'
        : type == 'video'
        ? '🎬 Video'
        : type == 'music'
        ? '🎵 Music'
        : '📎 Attachment';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF6D5BFF), width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              preview.length > 40 ? preview.substring(0, 40) + '...' : preview,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 18),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}