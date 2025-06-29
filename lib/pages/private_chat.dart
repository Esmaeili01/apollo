import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'user_profile.dart';

class PrivateChat extends StatefulWidget {
  const PrivateChat({required this.contact, super.key});

  final Map<String, dynamic> contact;

  @override
  State<PrivateChat> createState() => _PrivateChatState();
}

class _PrivateChatState extends State<PrivateChat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Map<String, dynamic>? _contactProfile;
  bool _sending = false;

  late final RealtimeChannel _messagesSub;
  RealtimeChannel? _statusSub;

  @override
  void initState() {
    super.initState();
    final completer = Completer();
    completer.future.then((_) {
      _subscribeToMessages();
      _subscribeToContactStatus();
    });
    _fetchInitialData(completer);
  }

  Future<void> _fetchInitialData(Completer completer) async {
    await Future.wait([_fetchContactProfile(), _fetchMessages()]);
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSub.unsubscribe();
    _statusSub?.unsubscribe();
    super.dispose();
  }

  void _subscribeToMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final contactId = widget.contact['id'];

    final channelName = 'public:messages:private_chat:${user.id}:$contactId';

    _messagesSub = Supabase.instance.client.channel(channelName).on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        // No filter here!
      ),
      (payload, [ref]) {
        final newMessage = payload['new'] as Map<String, dynamic>;
        // Only add if this message is for this chat
        if ((newMessage['sender_id'] == user.id &&
                newMessage['receiver_id'] == contactId) ||
            (newMessage['sender_id'] == contactId &&
                newMessage['receiver_id'] == user.id)) {
          if (mounted) {
            setState(() {
              if (!_messages.any((msg) => msg['id'] == newMessage['id'])) {
                _messages.add(newMessage);
                _messages.sort(
                  (a, b) => DateTime.parse(
                    a['created_at'],
                  ).compareTo(DateTime.parse(b['created_at'])),
                );
              }
            });
            _scrollToBottom();
          }
        }
      },
    );
    _messagesSub.subscribe((String status, [dynamic error]) {
      // ... (status handling as before)
    });
  }

  void _subscribeToContactStatus() {
    final contactId = widget.contact['id'];
    _statusSub = Supabase.instance.client.channel('public:profiles:status').on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: '*',
        schema: 'public',
        table: 'profiles',
        filter: 'id=eq.$contactId',
      ),
      (payload, [ref]) {
        if (mounted) {
          _fetchContactProfile();
        }
      },
    );
    _statusSub?.subscribe();
  }

  Future<void> _fetchContactProfile() async {
    try {
      final contactId = widget.contact['id'];
      final res =
          await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', contactId)
              .maybeSingle();
      if (mounted) {
        setState(() {
          _contactProfile = res;
        });
      }
    } catch (e) {
      print('Error fetching contact profile: $e');
    }
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final contactId = widget.contact['id'];

      final List messages = await Supabase.instance.client
          .from('messages')
          .select()
          .or(
            'and(sender_id.eq.${user.id},receiver_id.eq.$contactId),and(sender_id.eq.$contactId,receiver_id.eq.${user.id})',
          )
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages);
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _sending = false);
      return;
    }
    _messageController.clear();

    try {
      final contactId = widget.contact['id'];
      await Supabase.instance.client.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': contactId,
        'content': text,
        'type': 'text', // FIX: ADDED THIS BACK
      });
    } catch (e) {
      print('Error sending message: $e');
      _messageController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
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

  String _getStatusText() {
    if (_contactProfile == null) return '';
    final isOnline = _contactProfile!['is_online'] == true;
    if (isOnline) return 'online';
    final lastSeen = _contactProfile!['last_seen'];
    if (lastSeen == null) return 'last seen recently';
    final dt = DateTime.tryParse(lastSeen)?.toLocal();
    if (dt == null) return 'last seen recently';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24 && now.day == dt.day) {
      return 'last seen ${diff.inHours} hr ago';
    }
    if (diff.inHours < 48 && now.day - dt.day == 1) {
      return 'last seen yesterday at ${DateFormat('HH:mm').format(dt)}';
    }
    return 'last seen on ${DateFormat('MMM dd, yyyy').format(dt)} at ${DateFormat('HH:mm').format(dt)}';
  }

  void _showContactInfo() {
    if (_contactProfile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(profile: _contactProfile!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _contactProfile?['name'] ?? widget.contact['name'] ?? '';
    final avatarUrl =
        _contactProfile?['avatar_url'] ?? widget.contact['avatar_url'];
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
          onTap: _showContactInfo,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF46C2CB),
                backgroundImage:
                    avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                child:
                    (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(
                          name.isNotEmpty
                              ? name.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getStatusText(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                          final user =
                              Supabase.instance.client.auth.currentUser;
                          final isMe = msg['sender_id'] == user?.id;
                          return Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    isMe
                                        ? const LinearGradient(
                                          colors: [
                                            Color(0xFF6D5BFF),
                                            Color(0xFF46C2CB),
                                          ],
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
                                    color: Colors.black.withAlpha(20),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['content'] ?? '',
                                    style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      msg['created_at'] != null
                                          ? DateFormat('HH:mm').format(
                                            DateTime.parse(
                                              msg['created_at'],
                                            ).toLocal(),
                                          )
                                          : '',
                                      style: TextStyle(
                                        color:
                                            isMe
                                                ? Colors.white70
                                                : Colors.black38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Pin icon for multimedia
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file,
                        color: Color(0xFF6D5BFF),
                      ),
                      onPressed: () {
                        // TODO: Implement multimedia picker
                      },
                      tooltip: 'Attach file',
                    ),
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
                        onSubmitted: _sending ? null : (_) => _sendMessage(),
                      ),
                    ),
                    // Mic icon for voice recording
                    IconButton(
                      icon: const Icon(Icons.mic, color: Color(0xFF6D5BFF)),
                      onPressed: () {
                        // TODO: Implement voice recording
                      },
                      tooltip: 'Record voice',
                    ),
                    IconButton(
                      icon:
                          _sending
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF6D5BFF),
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
