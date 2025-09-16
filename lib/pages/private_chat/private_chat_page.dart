import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../user_profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../main.dart';
import 'dart:html' as html;
import 'dart:typed_data';

import 'models/message_type.dart';
import 'services/chat_service.dart';
import 'services/file_service.dart';
import 'widgets/message_bubble.dart';
import 'widgets/edit_message_input.dart';
import 'widgets/reply_widgets.dart';

class PrivateChat extends StatefulWidget {
  const PrivateChat({required this.contact, super.key});
  final Map<String, dynamic> contact;

  @override
  State<PrivateChat> createState() => _PrivateChatState();
}

class _PrivateChatState extends State<PrivateChat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _editController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Map<String, dynamic>? _contactProfile;
  bool _sending = false;
  Map<String, dynamic>? _editingMessage;
  Map<String, dynamic>? _replyToMessage;
  bool _notificationsEnabled = true;
  bool _notificationSettingLoaded = false;

  @override
  void initState() {
    super.initState();
    currentOpenChatContactId = widget.contact['id'];
    _fetchInitialData().then((_) {
      if (mounted) {
        _subscribeToMessages();
        _subscribeToContactStatus();
        _loadNotificationSetting();
      }
    });
    // Add scroll listener to mark messages as seen when scrolled into view
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Mark messages as seen when user actively scrolls
    if (_scrollController.hasClients) {
      _markVisibleMessagesAsSeen();
    }
  }

  bool get _isBlockedContact {
    final id = widget.contact['id'];
    return id == "0fd7896a-3c6d-45e9-b7b8-2239120426c5" ||
          id == "88ad8967-0fad-4b68-b012-708a2701a461";
  }
  @override
  void dispose() {
    currentOpenChatContactId = null;
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    // Don't unsubscribe all channels, let individual channels handle their own disposal
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchContactProfile(), _fetchMessages()]);
  }

  Future<void> _fetchContactProfile() async {
    final profile = await ChatService.fetchContactProfile(widget.contact['id']);
    if (mounted) {
      setState(() {
        _contactProfile = profile;
      });
    }
  }

  Future<void> _fetchMessages() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final messages = await ChatService.fetchMessages(widget.contact['id']);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final channelName = ChatService.getPrivateChatChannelName(
      user.id,
      widget.contact['id'],
    );
    final channel = Supabase.instance.client.channel(channelName)
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: 'INSERT', schema: 'public', table: 'messages'),
        (payload, [ref]) async {
          final newMessage = payload['new'] as Map<String, dynamic>;
          final isForThisChat =
              (newMessage['sender_id'] == user.id &&
                  newMessage['receiver_id'] == widget.contact['id']) ||
              (newMessage['sender_id'] == widget.contact['id'] &&
                  newMessage['receiver_id'] == user.id);
          if (isForThisChat) {
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
            final isMine = newMessage['sender_id'] == user.id;
            if (!isMine &&
                _notificationsEnabled &&
                html.document.visibilityState != 'visible') {
              final profile = await ChatService.fetchContactProfile(widget.contact['id']);
              if (html.Notification.permission != 'granted')
                await html.Notification.requestPermission();
              if (html.Notification.permission == 'granted') {
                html.Notification(
                  profile?['name'] ?? 'New message',
                  body: newMessage['content'] ?? 'Media message',
                  icon: profile?['avatar_url'],
                );
              }
            }
          }
        },
      )
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: 'UPDATE', schema: 'public', table: 'messages'),
        (payload, [ref]) {
          final updatedMessage = payload['new'] as Map<String, dynamic>;
          final isForThisChat =
              (updatedMessage['sender_id'] == user.id &&
                  updatedMessage['receiver_id'] == widget.contact['id']) ||
              (updatedMessage['sender_id'] == widget.contact['id'] &&
                  updatedMessage['receiver_id'] == user.id);
          if (isForThisChat && mounted) {
            setState(() {
              final idx = _messages.indexWhere(
                (msg) => msg['id'] == updatedMessage['id'],
              );
              if (idx != -1) _messages[idx] = updatedMessage;
            });
          }
        },
      );
    channel.subscribe((status, [error]) {
      if (status == 'CHANNEL_ERROR' || status == 'CLOSED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connection to chat lost: $error. Please check your internet and restart the app.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _subscribeToContactStatus() {
    final channel = Supabase.instance.client
        .channel('public:profiles:status')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: '*',
            schema: 'public',
            table: 'profiles',
            filter: 'id=eq.${widget.contact['id']}',
          ),
          (payload, [ref]) => _fetchContactProfile(),
        );
    channel.subscribe();
  }

  Future<void> _sendMessage() async {
  // Check if contact is blocked
  if (_isBlockedContact) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You cannot send messages to a blocked contact.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return; // Exit early
  }

  final text = _messageController.text.trim();
  if (text.isEmpty) return;

  setState(() => _sending = true);
  try {
    await ChatService.sendMessage(
      receiverId: widget.contact['id'],
      content: text,
      replyToId: _replyToMessage?['id'],
    );
    _messageController.clear();
    setState(() => _replyToMessage = null);
  } catch (e) {
    _messageController.text = text;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _sending = false);
  }
}

  Future<void> _handleAttachFile() async {
    setState(() => _sending = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final fileInfo = FileService.getFileInfo(file.extension);
      final url = await FileService.uploadFileToSupabase(file, fileInfo.bucket);
      await ChatService.sendMultimediaMessage(
        receiverId: widget.contact['id'],
        type: fileInfo.type,
        urls: [url],
        content: file.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload file: $e'),
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
    setState(() => _sending = true);
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });
      if (stream == null) throw 'Microphone not available.';
      final mediaRecorder = html.MediaRecorder(stream, {
        'mimeType': 'audio/webm',
      });
      final List<html.Blob> chunks = [];
      final completer = Completer<void>();
      mediaRecorder.addEventListener('dataavailable', (event) {
        final e = event as html.BlobEvent;
        if (e.data != null && e.data!.size > 0) chunks.add(e.data!);
      });
      mediaRecorder.addEventListener('stop', (event) => completer.complete());
      mediaRecorder.start();
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Recording...'),
          content: const Icon(Icons.mic, size: 48, color: Colors.red),
          actions: [
            TextButton(
              onPressed: () {
                mediaRecorder.stop();
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
      reader.onLoadEnd.listen(
        (_) => loadCompleter.complete(reader.result as Uint8List),
      );
      reader.readAsArrayBuffer(blob);
      final bytes = await loadCompleter.future;
      final file = PlatformFile(
        name: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
        size: bytes.length,
        bytes: bytes,
      );
      final url = await FileService.uploadFileToSupabase(file, 'voices');
      await ChatService.sendMultimediaMessage(
        receiverId: widget.contact['id'],
        type: MessageType.voice.name,
        urls: [url],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not record voice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ChatService.deleteMessage(message['id'], message['sender_id']);
      setState(() {
        _messages.removeWhere((m) => m['id'] == message['id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editMessage(
    Map<String, dynamic> message,
    String newText,
  ) async {
    try {
      await ChatService.editMessage(message['id'], message['sender_id'], newText);
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == message['id']);
        if (idx != -1) _messages[idx]['content'] = newText;
        _editingMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message edited'),
            backgroundColor: Color(0xFF46C2CB),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to edit message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final res = await Supabase.instance.client
          .from('contacts')
          .select('notifications_enabled')
          .eq('user_id', userId)
          .eq('contact_id', widget.contact['id'])
          .maybeSingle();
      setState(() {
        _notificationsEnabled = res?['notifications_enabled'] ?? true;
        _notificationSettingLoaded = true;
      });
    } catch (e) {
      // Removed print statement
    }
  }

  Future<void> _toggleNotification() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final current = _notificationsEnabled;
      final newValue = !current;
      await ChatService.toggleNotification(widget.contact['id'], newValue);
      setState(() => _notificationsEnabled = newValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Notifications enabled for this chat'
                : 'Notifications disabled for this chat',
          ),
          backgroundColor: newValue ? const Color(0xFF46C2CB) : Colors.red,
        ),
      );
    } catch (e) {
      // Removed print statement
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
        // Mark unseen messages as seen when scrolling to bottom
        _markVisibleMessagesAsSeen();
      }
    });
  }

  void _markVisibleMessagesAsSeen() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    // Mark all unseen messages from the contact as seen
    for (final message in _messages) {
      if (message['sender_id'] == widget.contact['id'] && !(message['is_seen'] ?? false)) {
        ChatService.markMessageAsSeen(message['id']);
        // Update local state to avoid redundant calls
        message['is_seen'] = true;
        message['last_seen'] = DateTime.now().toUtc().toIso8601String();
      }
    }
  }

  String _getStatusText() {
    if (_contactProfile == null) return 'loading...';
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
      return 'last seen today at ${DateFormat('HH:mm').format(dt)}';
    }
    return 'last seen on ${DateFormat('MMM dd').format(dt)}';
  }

  void _showContactInfo() {
    if (_contactProfile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(profile: _contactProfile!),
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
            children: [
              CircleAvatar(
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
        actions: [
          if (_notificationSettingLoaded)
            IconButton(
              icon: Icon(
                _notificationsEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: Colors.white,
              ),
              tooltip: _notificationsEnabled
                  ? 'Disable notifications for this chat'
                  : 'Enable notifications for this chat',
              onPressed: _toggleNotification,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFF5F6FA)),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isMe =
                            msg['sender_id'] ==
                            Supabase.instance.client.auth.currentUser?.id;
                        return _editingMessage != null &&
                                _editingMessage!['id'] == msg['id']
                            ? EditMessageInput(
                                initialText: msg['content'] ?? '',
                                onCancel: () =>
                                    setState(() => _editingMessage = null),
                                onSave: (newText) => _editMessage(msg, newText),
                              )
                            : MessageBubble(
                                message: msg,
                                isMe: isMe,
                                isDelivered: msg['is_delivered'] ?? false,
                                isSeen: msg['is_seen'] ?? false,
                                onEdit: (m) => setState(() {
                                  _editingMessage = m;
                                  _editController.text = m['content'] ?? '';
                                }),
                                onDelete: _deleteMessage,
                                onReply: (m) =>
                                    setState(() => _replyToMessage = m),
                                onShowOptions: (m, isMe) =>
                                    _showMessageOptions(context, m, isMe),
                                getMessageById: (id) {
                                  final matches = _messages.where(
                                    (msg) => msg['id'] == id,
                                  );
                                  return matches.isNotEmpty
                                      ? matches.first
                                      : null;
                                },
                              );
                      },
                    ),
            ),
            if (_replyToMessage != null)
              ReplyPreview(
                message: _replyToMessage!,
                onCancel: () => setState(() => _replyToMessage = null),
                getMessageById: (id) {
                  final matches = _messages.where((msg) => msg['id'] == id);
                  return matches.isNotEmpty ? matches.first : null;
                },
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
                  _isBlockedContact
                    ? Expanded(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'You cannot send messages to this contact.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    : Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Message',
                          ),
                          onSubmitted: _sending ? null : (_) => _sendMessage(),
                          enabled: !_sending, // Optional: disable while sending
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.mic,
                        color: kIsWeb ? const Color(0xFF6D5BFF) : Colors.grey,
                      ),
                      onPressed: _sending || !kIsWeb
                          ? null
                          : _handleRecordVoice,
                      tooltip: kIsWeb
                          ? 'Record voice'
                          : 'Voice recording web-only',
                    ),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.send, color: Color(0xFF6D5BFF)),
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

  void _showMessageOptions(
    BuildContext context,
    Map<String, dynamic> message,
    bool isMe,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFF6D5BFF)),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyToMessage = message);
                },
              ),
              if (isMe && message['type'] == 'text')
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF46C2CB)),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = message;
                      _editController.text = message['content'] ?? '';
                    });
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}