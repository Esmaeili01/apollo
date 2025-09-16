import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../models/message_type.dart';
import 'voice_player.dart';

class MessageContent extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const MessageContent({
    super.key,
    required this.message,
    required this.isMe,
  });

  void _downloadFile(String url, String filename) {
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
  }

  @override
  Widget build(BuildContext context) {
    final type = MessageType.fromString(message['type'] ?? 'text');
    final content = message['content'] as String? ?? '';
    final mediaUrl = (message['media_url'] as List?)?.firstOrNull as String?;
    final textColor = isMe ? Colors.white : Colors.black87;

    switch (type) {
      case MessageType.text:
        return Text(content, style: TextStyle(color: textColor, fontSize: 16));
      case MessageType.image:
        if (mediaUrl == null) return const Text('📷 Image not available');
        return Stack(
          children: [
            SizedBox(
              width: 300,
              height: 450,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const CircularProgressIndicator(),
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _downloadFile(
                  mediaUrl,
                  'image.${mediaUrl.split('.').lastOrNull ?? 'jpg'}',
                ),
              ),
            ),
          ],
        );
      case MessageType.voice:
        if (mediaUrl == null)
          return const Text('🎤 Voice message not available');
        return VoiceMessagePlayer(mediaUrl: mediaUrl, isMe: isMe);
      case MessageType.video:
      case MessageType.doc:
      case MessageType.music:
        final icon = switch (type) {
          MessageType.video => Icons.videocam,
          MessageType.music => Icons.music_note,
          _ => Icons.insert_drive_file,
        };
        final fallbackFilename =
            'download.${mediaUrl?.split('.').lastOrNull ?? 'dat'}';
        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.only(
                right: 32,
              ), // Space for download icon
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: textColor.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      content.isNotEmpty ? content : 'Attachment',
                      style: TextStyle(color: textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (mediaUrl != null)
              Positioned(
                bottom: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(
                    Icons.download_rounded,
                    color: textColor,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _downloadFile(
                    mediaUrl,
                    content.isNotEmpty ? content : fallbackFilename,
                  ),
                ),
              ),
          ],
        );
    }
  }
}