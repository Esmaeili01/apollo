import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'group_profile.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:intl/intl.dart';

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
  bool _sending = false;
  RealtimeChannel? _messagesSub;

  @override
  void initState() {
    super.initState();
    _fetchGroupData();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSub?.unsubscribe();
    super.dispose();
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
    if (mounted) setState(() => _isLoading = true);
    try {
      if (_groupId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final List messages = await Supabase.instance.client
          .from('messages')
          .select('''
            id,
            content,
            created_at,
            type,
            media_url,
            profiles!messages_sender_id_fkey(
              id,
              name,
              username,
              avatar_url
            )
          ''')
          .eq('group_id', _groupId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages =
              List<Map<String, dynamic>>.from(messages).map((message) {
                final profile = message['profiles'] as Map<String, dynamic>;
                return {
                  ...message,
                  'sender': {
                    'id': profile['id'],
                    'name': profile['name'] ?? profile['username'] ?? 'Unknown',
                    'username': profile['username'],
                    'avatar_url': profile['avatar_url'],
                  },
                };
              }).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error fetching messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  Future<void> _leaveGroup() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _groupId == null) return;
    try {
      await Supabase.instance.client
          .from('group_members')
          .delete()
          .eq('group_id', _groupId)
          .eq('user_id', user.id);
      if (mounted) {
        Navigator.of(context).pop(); // Pop the dialog
        Navigator.of(context).pop(); // Pop the group chat page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the group.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Pop the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper to get current user's role in the group
  int? get _currentUserRole {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final member = _members.firstWhere(
      (m) => m['user_id'] == user.id,
      orElse: () => {},
    );
    return member['role'] as int?;
  }

  // Delete group and all memberships
  Future<void> _deleteGroup() async {
    if (_groupId == null) return;
    try {
      await Supabase.instance.client
          .from('group_members')
          .delete()
          .eq('group_id', _groupId);
      await Supabase.instance.client.from('groups').delete().eq('id', _groupId);
      if (mounted) {
        Navigator.of(context).pop(); // Pop the dialog
        Navigator.of(context).pop(); // Pop the group chat page
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group deleted.')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  ({String bucket, String type}) _getFileInfo(String? extension) {
    final ext = extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) {
      return (bucket: 'pics', type: MessageType.image.name);
    }
    if (['mp4', 'mov', 'avi', 'webm'].contains(ext)) {
      return (bucket: 'vids', type: MessageType.video.name);
    }
    if (['mp3', 'wav', 'ogg'].contains(ext)) {
      return (bucket: 'musics', type: MessageType.music.name);
    }
    // WebM is a common format for browser-based recording
    if (ext == 'm4a' || ext == 'webm') {
      return (bucket: 'voices', type: MessageType.voice.name);
    }
    return (bucket: 'docs', type: MessageType.doc.name);
  }

  Future<String?> _uploadFileToSupabase(
    PlatformFile file,
    String bucket,
  ) async {
    try {
      final storage = Supabase.instance.client.storage.from(bucket);
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final fileExt = file.extension ?? 'bin';
      final filePath =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final bytes = file.bytes;

      if (bytes == null) {
        throw 'File data is empty.';
      }

      await storage.uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: false),
      );
      return storage.getPublicUrl(filePath);
    } on StorageException catch (e) {
      print('Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } catch (e) {
      print('Unexpected error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _handleAttachFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileInfo = _getFileInfo(file.extension);

    // Show a sending indicator while uploading
    setState(() => _sending = true);
    final url = await _uploadFileToSupabase(file, fileInfo.bucket);
    if (mounted) setState(() => _sending = false);

    if (url == null) return; // Error was already shown

    // Pass the original filename as content for display purposes
    await _sendMultimediaMessage(
      type: fileInfo.type,
      urls: [url],
      content: file.name,
    );
  }

  Future<void> _sendMultimediaMessage({
    required String type,
    required List<String> urls,
    String? content,
  }) async {
    setState(() => _sending = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _groupId == null) {
      setState(() => _sending = false);
      return;
    }
    try {
      await Supabase.instance.client.from('messages').insert({
        'group_id': _groupId,
        'sender_id': user.id,
        'content': content,
        'type': type,
        'is_multimedia': true,
        'media_url': urls,
      });
    } catch (e) {
      print('Error sending multimedia message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleRecordVoice() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recording is only available on the web.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });
      if (stream == null) {
        throw 'Microphone not available.';
      }

      final mediaRecorder = html.MediaRecorder(stream, {
        'mimeType': 'audio/webm',
      });
      final List<html.Blob> chunks = [];
      final completer = Completer<void>();

      mediaRecorder.addEventListener('dataavailable', (event) {
        final e = event as html.BlobEvent;
        if (e.data != null && e.data!.size > 0) {
          chunks.add(e.data!);
        }
      });

      mediaRecorder.addEventListener('stop', (event) {
        completer.complete(); // Mark as finished
      });

      mediaRecorder.start();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('Recording...'),
              content: const Icon(Icons.mic, size: 48, color: Colors.red),
              actions: [
                TextButton(
                  onPressed: () {
                    mediaRecorder.stop(); // This triggers the 'stop' event
                    Navigator.of(context).pop();
                  },
                  child: const Text('Stop'),
                ),
              ],
            ),
      );

      await completer.future;
      stream.getTracks().forEach((track) => track.stop());
      if (chunks.isEmpty) return;

      final blob = html.Blob(chunks, 'audio/webm');
      final reader = html.FileReader();
      final loadCompleter = Completer<Uint8List>();

      reader.onLoadEnd.listen((_) {
        loadCompleter.complete(reader.result as Uint8List);
      });
      reader.readAsArrayBuffer(blob);
      final bytes = await loadCompleter.future;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final file = PlatformFile(
        name: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
        size: bytes.length,
        bytes: bytes,
      );

      setState(() => _sending = true);
      final url = await _uploadFileToSupabase(file, 'voices');
      if (mounted) setState(() => _sending = false);

      if (url != null) {
        await _sendMultimediaMessage(type: 'voice', urls: [url]);
      }
    } catch (e) {
      print('Error handling voice recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not record voice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _subscribeToMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _groupId == null) return;
    final channelName = 'group-chat-$_groupId';
    _messagesSub = Supabase.instance.client.channel(channelName).on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'INSERT', schema: 'public', table: 'messages'),
      (payload, [ref]) {
        final newMessage = payload['new'] as Map<String, dynamic>;
        if (newMessage['group_id'] == _groupId && mounted) {
          setState(() {
            if (!_messages.any((msg) => msg['id'] == newMessage['id'])) {
              // Add sender info for UI
              _messages.add({
                ...newMessage,
                'sender': {
                  'id': newMessage['sender_id'],
                  'name': '', // Optionally fetch name/avatar if needed
                  'username': '',
                  'avatar_url': '',
                },
              });
              _messages.sort(
                (a, b) => DateTime.parse(
                  a['created_at'],
                ).compareTo(DateTime.parse(b['created_at'])),
              );
            }
          });
          _scrollToBottom();
        }
      },
    );
    _messagesSub?.subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _groupId == null) {
      setState(() => _sending = false);
      return;
    }
    _messageController.clear();

    try {
      await Supabase.instance.client.from('messages').insert({
        'group_id': _groupId,
        'sender_id': user.id,
        'content': text,
        'type': MessageType.text.name,
      });
    } catch (e) {
      print('Error sending message: $e');
      _messageController.text = text; // Restore text on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: \\${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
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
        iconTheme: const IconThemeData(color: Colors.white),
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            offset: const Offset(0, 50),
            onSelected: (value) {
              if (value == 'search') {
                // TODO: Implement search functionality
              } else if (value == 'leave') {
                final role = _currentUserRole;
                if (role == 2) {
                  // Admin or Owner: show delete group dialog
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Leave and Delete Group'),
                          content: const Text(
                            'As the owner, leaving will delete the group for everyone. Are you sure you want to continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: _deleteGroup,
                              child: const Text(
                                'Delete Group',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );
                } else {
                  // Regular member: show leave dialog
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Leave Group'),
                          content: const Text(
                            'Are you sure you want to leave this group?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: _leaveGroup,
                              child: const Text(
                                'Leave',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );
                }
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'search',
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('Search'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: const [
                        Icon(Icons.exit_to_app, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Leave Group',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
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
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final user =
                              Supabase.instance.client.auth.currentUser;
                          final isMe = msg['sender']?['id'] == user?.id;
                          return _GroupMessageBubble(
                            message: msg,
                            isMe: isMe,
                            members: _members,
                          );
                        },
                      ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file,
                        color: Color(0xFF6D5BFF),
                      ),
                      onPressed: _sending ? null : _handleAttachFile,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Message',
                        ),
                        onSubmitted: _sending ? null : (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.mic,
                        color: kIsWeb ? const Color(0xFF6D5BFF) : Colors.grey,
                      ),
                      onPressed:
                          _sending || !kIsWeb ? null : _handleRecordVoice,
                      tooltip:
                          kIsWeb ? 'Record voice' : 'Voice recording web-only',
                    ),
                    IconButton(
                      icon:
                          _sending
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                              : const Icon(
                                Icons.send,
                                color: Color(0xFF6D5BFF),
                              ),
                      onPressed: _sending ? null : _sendMessage,
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

class _GroupMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final List<Map<String, dynamic>> members;

  const _GroupMessageBubble({
    required this.message,
    required this.isMe,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final senderId = message['sender']?['id'];
    final sender = members.firstWhere(
      (m) => m['user_id'] == senderId,
      orElse: () => {},
    );
    final senderName = message['sender']?['name'] ?? 'Unknown';
    final senderAvatar = message['sender']?['avatar_url'] ?? '';
    final senderRole = sender != null ? sender['role'] as int? : null;
    final senderRoleText = switch (senderRole) {
      1 => 'Admin',
      2 => 'Owner',
      _ => null,
    };
    final nameRow = Row(
      children: [
        Text(
          senderName,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        if (senderRoleText != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: senderRole == 2 ? Colors.deepPurple : Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              senderRoleText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF46C2CB),
                backgroundImage:
                    senderAvatar.isNotEmpty ? NetworkImage(senderAvatar) : null,
                child:
                    senderAvatar.isEmpty
                        ? Text(
                          senderName.isNotEmpty
                              ? senderName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : null,
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              gradient:
                  isMe
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
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                nameRow,
                const SizedBox(height: 2),
                _GroupMessageContent(message: message, isMe: isMe),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMessageContent extends StatelessWidget {
  const _GroupMessageContent({required this.message, required this.isMe});

  final Map<String, dynamic> message;
  final bool isMe;

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
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            loadingBuilder:
                (context, child, progress) =>
                    progress == null
                        ? child
                        : const CircularProgressIndicator(),
            errorBuilder:
                (_, __, ___) =>
                    Icon(Icons.broken_image, color: textColor.withOpacity(0.8)),
          ),
        );

      case MessageType.voice:
        if (mediaUrl == null)
          return const Text('🎤 Voice message not available');
        return _VoiceMessagePlayer(mediaUrl: mediaUrl, isMe: isMe);

      case MessageType.video:
      case MessageType.doc:
      case MessageType.music:
      default:
        final icon = switch (type) {
          MessageType.video => Icons.videocam,
          MessageType.music => Icons.music_note,
          _ => Icons.insert_drive_file,
        };
        final fallbackFilename =
            'download.${mediaUrl?.split('.').lastOrNull ?? 'dat'}';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor.withOpacity(0.8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                content.isNotEmpty ? content : 'Attachment',
                style: TextStyle(color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.download_rounded, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed:
                  mediaUrl == null
                      ? null
                      : () => _downloadFile(
                        mediaUrl,
                        content.isNotEmpty ? content : fallbackFilename,
                      ),
            ),
          ],
        );
    }
  }
}

enum MessageType {
  text,
  image,
  video,
  voice,
  music,
  doc;

  static MessageType fromString(String type) {
    return MessageType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => MessageType.doc,
    );
  }
}

// Add the _VoiceMessagePlayer widget for playing voice messages
class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({required this.mediaUrl, required this.isMe});
  final String mediaUrl;
  final bool isMe;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  @override
  void initState() {
    super.initState();

    // Listen to player state changes.
    _playerStateChangeSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to audio duration changes.
    _durationSubscription = _audioPlayer.onDurationChanged.listen((
      newDuration,
    ) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    // Listen to audio position changes.
    _positionSubscription = _audioPlayer.onPositionChanged.listen((
      newPosition,
    ) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    // Reset position when audio completes.
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
        });
      }
    });

    // Set the audio source once initially. This helps fetch the duration.
    _audioPlayer.setSourceUrl(widget.mediaUrl);
  }

  @override
  void dispose() {
    // Cancel all subscriptions and release the player.
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Helper to format duration to a MM:SS string.
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : const Color(0xFF6D5BFF);
    final inactiveColor =
        widget.isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade400;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () async {
            if (_isPlaying) {
              await _audioPlayer.pause();
            } else {
              // If position is at the end, seek to start before playing.
              if (_position >= _duration && _duration > Duration.zero) {
                await _audioPlayer.seek(Duration.zero);
              }
              await _audioPlayer.play(UrlSource(widget.mediaUrl));
            }
          },
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: color,
            size: 32,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_duration > Duration.zero)
                Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) async {
                    final position = Duration(seconds: value.toInt());
                    await _audioPlayer.seek(position);
                  },
                  activeColor: color,
                  inactiveColor: inactiveColor,
                ),
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: TextStyle(fontSize: 12, color: color.withOpacity(0.9)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
