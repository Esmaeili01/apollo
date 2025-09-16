import 'package:flutter/material.dart';

class MessageStatusIcons extends StatelessWidget {
  final bool isDelivered;
  final bool isSeen;
  final Color color;

  const MessageStatusIcons({
    super.key,
    required this.isDelivered,
    required this.isSeen,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        if (!isDelivered)
          Icon(Icons.access_time, size: 16, color: color)
        else if (isDelivered && !isSeen)
          Icon(Icons.done, size: 16, color: color)
        else if (isDelivered && isSeen)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.done_all, size: 16, color: Colors.black)],
          ),
      ],
    );
  }
}