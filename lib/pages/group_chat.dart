import 'package:flutter/material.dart';
import 'group_profile.dart';

class GroupChatPage extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupChatPage({required this.group, Key? key}) : super(key: key);

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    // TODO: Fetch group messages and members
    _fetchGroupData();
  }

  Future<void> _fetchGroupData() async {
    // TODO: Replace with real fetch logic
    setState(() {
      _isLoading = false;
      _members = widget.group['members'] ?? [];
      _messages = [
        // Example messages
        {
          'id': '1',
          'sender': {'name': 'Alice', 'avatar_url': ''},
          'content': 'Hello group!',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': '2',
          'sender': {'name': 'Bob', 'avatar_url': ''},
          'content': 'Hi Alice!',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
    });
  }

  void _showGroupProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupProfilePage(group: widget.group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group['name'] ?? 'Group';
    final memberCount = _members.length;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: GestureDetector(
          onTap: _showGroupProfile,
          child: Row(
            children: [
              const Icon(Icons.groups, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      memberCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFF5F6FA)),
        child: Column(
          children: [
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final sender = msg['sender'] as Map<String, dynamic>;
                          final avatarUrl = sender['avatar_url'] as String?;
                          final senderName = sender['name'] as String? ?? '';
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF46C2CB),
                                  backgroundImage:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                  child:
                                      (avatarUrl == null || avatarUrl.isEmpty)
                                          ? Text(
                                            senderName.isNotEmpty
                                                ? senderName
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                          : null,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(20),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF6D5BFF),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg['content'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          msg['created_at'] != null
                                              ? msg['created_at']
                                                  .toString()
                                                  .substring(11, 16)
                                              : '',
                                          style: const TextStyle(
                                            color: Colors.black38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                        ),
                        onSubmitted: (_) {}, // TODO: send message
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF6D5BFF)),
                      onPressed: () {}, // TODO: send message
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
