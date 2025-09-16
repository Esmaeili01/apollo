import 'package:flutter/material.dart';

class EditMessageInput extends StatefulWidget {
  final String initialText;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

  const EditMessageInput({
    super.key,
    required this.initialText,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<EditMessageInput> createState() => _EditMessageInputState();
}

class _EditMessageInputState extends State<EditMessageInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration.collapsed(
                hintText: 'Edit message',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: widget.onCancel,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF46C2CB)),
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isNotEmpty) widget.onSave(text);
            },
          ),
        ],
      ),
    );
  }
}