import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'user_profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../main.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

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
  }

  @override
  void dispose() {
    currentOpenChatContactId = null;
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    Supabase.instance.client.channel('*').unsubscribe();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchContactProfile(), _fetchMessages()]);
  }

  Future<void> _fetchContactProfile() async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.contact['id'])
          .maybeSingle();
      if (mounted) {
        setState(() {
          _contactProfile = res;
        });
      }
    } catch (e) {
      // Removed print statement
    }
  }

  Future<void> _fetchMessages() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final messages = await Supabase.instance.client
          .from('messages')
          .select()
          .or(
            'and(sender_id.eq.${user.id},receiver_id.eq.${widget.contact['id']}),and(sender_id.eq.${widget.contact['id']},receiver_id.eq.${user.id})',
          )
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages);
        });
        _scrollToBottom();
        _markReceivedMessagesAsSeen();
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

  Future<void> _markMessageAsSeen(String messageId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'is_seen': true,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId);
    } catch (e) {
      // Removed print statement
    }
  }

  Future<void> _markReceivedMessagesAsSeen() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'is_seen': true,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('sender_id', widget.contact['id'])
          .eq('receiver_id', user.id)
          .eq('is_seen', false);
    } catch (e) {
      // Removed print statement
    }
  }

  String getPrivateChatChannelName(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'private-chat-${ids[0]}-${ids[1]}';
  }

  void _subscribeToMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final channelName = getPrivateChatChannelName(
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
              final profile = await Supabase.instance.client
                  .from('profiles')
                  .select()
                  .eq('id', widget.contact['id'])
                  .maybeSingle();
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
            if (!isMine) _markMessageAsSeen(newMessage['id']);
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
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.contact['id'],
        'content': text,
        'type': MessageType.text.name,
        'is_delivered': true,
        'is_seen': false,
        if (_replyToMessage != null) 'reply_to_id': _replyToMessage!['id'],
      });
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

  ({String bucket, String type}) _getFileInfo(String? extension) {
    final ext = extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext))
      return (bucket: 'pics', type: MessageType.image.name);
    if (['mp4', 'mov', 'avi', 'webm'].contains(ext))
      return (bucket: 'vids', type: MessageType.video.name);
    if (['mp3', 'wav', 'ogg'].contains(ext))
      return (bucket: 'musics', type: MessageType.music.name);
    if (ext == 'm4a' || ext == 'webm')
      return (bucket: 'voices', type: MessageType.voice.name);
    return (bucket: 'docs', type: MessageType.doc.name);
  }

  Future<String> _uploadFileToSupabase(PlatformFile file, String bucket) async {
    final storage = Supabase.instance.client.storage.from(bucket);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final fileExt = file.extension ?? 'bin';
    final filePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final bytes = file.bytes;
    if (bytes == null) throw 'File data is empty.';
    await storage.uploadBinary(
      filePath,
      bytes,
      fileOptions: const FileOptions(upsert: false),
    );
    return storage.getPublicUrl(filePath);
  }

  Future<void> _handleAttachFile() async {
    setState(() => _sending = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final fileInfo = _getFileInfo(file.extension);
      final url = await _uploadFileToSupabase(file, fileInfo.bucket);
      await _sendMultimediaMessage(
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

  Future<void> _sendMultimediaMessage({
    required String type,
    required List<String> urls,
    String? content,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('messages').insert({
      'sender_id': user.id,
      'receiver_id': widget.contact['id'],
      'content': content,
      'type': type,
      'is_multimedia': true,
      'media_url': urls,
      'is_delivered': true,
      'is_seen': false,
    });
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
      final url = await _uploadFileToSupabase(file, 'voices');
      await _sendMultimediaMessage(type: MessageType.voice.name, urls: [url]);
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || message['sender_id'] != user.id) return;
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', message['id']);
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || message['sender_id'] != user.id) return;
      await Supabase.instance.client
          .from('messages')
          .update({'content': newText})
          .eq('id', message['id']);
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
      await Supabase.instance.client
          .from('contacts')
          .update({'notifications_enabled': newValue})
          .eq('user_id', userId)
          .eq('contact_id', widget.contact['id']);
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
      }
    });
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
                            ? _EditMessageInput(
                                initialText: msg['content'] ?? '',
                                onCancel: () =>
                                    setState(() => _editingMessage = null),
                                onSave: (newText) => _editMessage(msg, newText),
                              )
                            : _MessageBubble(
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
              _ReplyPreview(
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

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDelivered;
  final bool isSeen;
  final void Function(Map<String, dynamic> message)? onEdit;
  final void Function(Map<String, dynamic> message)? onDelete;
  final void Function(Map<String, dynamic> message)? onReply;
  final void Function(Map<String, dynamic> message, bool isMe)? onShowOptions;
  final Map<String, dynamic>? Function(String id)? getMessageById;

  const _MessageBubble({
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
                _ReplyBubblePreview(
                  repliedMessage: getMessageById!(message['reply_to_id']),
                  isMe: isMe,
                ),
              _MessageContent(message: message, isMe: isMe),
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
                _MessageStatusIcons(
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

class _MessageStatusIcons extends StatelessWidget {
  final bool isDelivered;
  final bool isSeen;
  final Color color;

  const _MessageStatusIcons({
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

class _MessageContent extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _MessageContent({required this.message, required this.isMe});

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
        return _VoiceMessagePlayer(mediaUrl: mediaUrl, isMe: isMe);
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

class _VoiceMessagePlayer extends StatefulWidget {
  final String mediaUrl;
  final bool isMe;

  const _VoiceMessagePlayer({required this.mediaUrl, required this.isMe});

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
    _audioPlayer.setSourceUrl(widget.mediaUrl);
    _playerStateChangeSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((
      newDuration,
    ) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((
      newPosition,
    ) {
      if (mounted) setState(() => _position = newPosition);
    });
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

@override
Widget build(BuildContext context) {
  final color = widget.isMe ? Colors.white : const Color(0xFF6D5BFF);
  final inactiveColor = widget.isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade400;

  return Stack(
    children: [
      Container(
        padding: const EdgeInsets.only(right: 32), // Space for download icon
        constraints: const BoxConstraints(maxWidth: 200), // Limit width
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    if (_isPlaying) {
                      await _audioPlayer.pause();
                    } else {
                      if (_position >= _duration && _duration > Duration.zero) {
                        await _audioPlayer.seek(Duration.zero);
                      }
                      await _audioPlayer.play(UrlSource(widget.mediaUrl));
                    }
                  },
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: color, size: 32),
                ),
                const SizedBox(width: 8),
                if (_duration > Duration.zero)
                  Flexible(
                    child: Slider(
                      value: _position.inSeconds.toDouble(),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) async {
                        final position = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(position);
                      },
                      activeColor: color,
                      inactiveColor: inactiveColor,
                    ),
                  ),
              ],
            ),
            if (_duration > Duration.zero)
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

class _EditMessageInput extends StatefulWidget {
  final String initialText;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

  const _EditMessageInput({
    required this.initialText,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_EditMessageInput> createState() => _EditMessageInputState();
}

class _EditMessageInputState extends State<_EditMessageInput> {
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

class _ReplyBubblePreview extends StatelessWidget {
  final Map<String, dynamic>? repliedMessage;
  final bool isMe;

  const _ReplyBubblePreview({required this.repliedMessage, required this.isMe});

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

class _ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onCancel;
  final Map<String, dynamic>? Function(String id) getMessageById;

  const _ReplyPreview({
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
