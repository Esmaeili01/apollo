import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Map<String, dynamic> _groupInfo = {};
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _fetchGroupData();
  }

  Future<void> _fetchGroupData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // If group has an ID, fetch from database, otherwise use the passed data
      if (widget.group['id'] != null) {
        _groupId = widget.group['id'];
        await _fetchExistingGroup();
      } else {
        // This is a newly created group, create it in database
        await _createNewGroup();
      }

      // Fetch members and messages
      await Future.wait([_fetchMembers(), _fetchMessages()]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewGroup() async {
    final user = Supabase.instance.client.auth.currentUser!;

    // Create the group
    final groupResponse =
        await Supabase.instance.client
            .from('groups')
            .insert({
              'name': widget.group['name'],
              'bio': widget.group['bio'],
              'is_public': widget.group['is_public'],
              'invite_link': widget.group['invite_link'],
              'avatar_url': widget.group['avatar_url'],
              'creator_id': user.id,
              'can_send_message': true,
              'can_send_media': true,
              'can_add_members': true,
              'can_pin_message': true,
              'can_change_info': true,
              'can_delete_message': false,
            })
            .select()
            .single();

    _groupId = groupResponse['id'];
    _groupInfo = groupResponse;

    // Add creator as first member
    await Supabase.instance.client.from('group_members').insert({
      'group_id': _groupId,
      'user_id': user.id,
      'role': 2, // 2 = owner
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _fetchExistingGroup() async {
    final response =
        await Supabase.instance.client
            .from('groups')
            .select()
            .eq('id', _groupId)
            .single();

    _groupInfo = response;
  }

  Future<void> _fetchMembers() async {
    try {
      final response = await Supabase.instance.client
          .from('group_members')
          .select('''
            user_id,
            role,
            joined_at,
            profiles!inner(
              id,
              name,
              username,
              avatar_url,
              bio
            )
          ''')
          .eq('group_id', _groupId);

      setState(() {
        _members =
            (response as List).map((member) {
              final profile = member['profiles'] as Map<String, dynamic>;
              final role = member['role'] as int? ?? 0;

              String roleText = '';
              switch (role) {
                case 0:
                  roleText = 'Member';
                  break;
                case 1:
                  roleText = 'Admin';
                  break;
                case 2:
                  roleText = 'Owner';
                  break;
              }

              return {
                'user_id': member['user_id'],
                'role': role,
                'role_text': roleText,
                'joined_at': member['joined_at'],
                'name': profile['name'] ?? profile['username'] ?? 'Unknown',
                'username': profile['username'],
                'avatar_url': profile['avatar_url'],
                'bio': profile['bio'],
              };
            }).toList();
      });
    } catch (e) {
      print('Error fetching members: $e');
      setState(() {
        _members = [];
      });
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await Supabase.instance.client
          .from('group_messages')
          .select('''
            id,
            content,
            created_at,
            profiles!inner(
              id,
              name,
              username,
              avatar_url
            )
          ''')
          .eq('group_id', _groupId)
          .order('created_at', ascending: true);

      setState(() {
        _messages =
            (response as List).map((message) {
              final profile = message['profiles'] as Map<String, dynamic>;
              return {
                'id': message['id'],
                'content': message['content'],
                'created_at': message['created_at'],
                'sender': {
                  'id': profile['id'],
                  'name': profile['name'] ?? profile['username'] ?? 'Unknown',
                  'username': profile['username'],
                  'avatar_url': profile['avatar_url'],
                },
              };
            }).toList();
      });
    } catch (e) {
      print('Error fetching messages: $e');
      setState(() {
        _messages = [];
      });
    }
  }

  void _showGroupProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupProfilePage(group: _groupInfo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _groupInfo['name'] ?? widget.group['name'] ?? 'Group';
    final memberCount = _members.length;
    final groupAvatarUrl = _groupInfo['avatar_url'];

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
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF46C2CB),
                backgroundImage:
                    groupAvatarUrl != null && groupAvatarUrl.isNotEmpty
                        ? NetworkImage(groupAvatarUrl)
                        : null,
                child:
                    (groupAvatarUrl == null || groupAvatarUrl.isEmpty)
                        ? const Icon(
                          Icons.groups,
                          color: Colors.white,
                          size: 20,
                        )
                        : null,
              ),
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
                                              ? DateTime.parse(
                                                msg['created_at'],
                                              ).toString().substring(11, 16)
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
