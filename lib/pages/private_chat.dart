import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'user_profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// dart:html is web-only. We conditionally import it.
import 'dart:html' as html;
import 'dart:typed_data';

// NEW: Import for the audio player.
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

// THE REST OF THE PrivateChat WIDGET REMAINS THE SAME...
// SCROLL DOWN TO THE _MessageBubble and _MessageContent WIDGETS FOR THE CHANGES.
// (For brevity, I'm omitting the unchanged parts of the PrivateChat class)

class PrivateChat extends StatefulWidget {
  const PrivateChat({required this.contact, super.key});
  final Map<String, dynamic> contact;
  @override
  State<PrivateChat> createState() => _PrivateChatState();
}

class _PrivateChatState extends State<PrivateChat> {
  // ... All previous state variables and methods (_messageController, _fetchMessages, etc.)
  // are here and unchanged.

  // --- OMITTING UNCHANGED METHODS FOR BREVITY ---
  // _fetchInitialData, _subscribeToMessages, _subscribeToContactStatus,
  // _fetchContactProfile, _fetchMessages, _scrollToBottom, _sendMessage,
  // _getStatusText, _showContactInfo, _getFileInfo, _uploadFileToSupabase,
  // _handleAttachFile, _handleRecordVoice, _sendMultimediaMessage
  // ARE ALL IDENTICAL TO THE PREVIOUS VERSION.
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Map<String, dynamic>? _contactProfile;
  bool _sending = false;

  late final RealtimeChannel _messagesSub;
  RealtimeChannel? _statusSub;

  // Add: Edit message state
  Map<String, dynamic>? _editingMessage;
  final TextEditingController _editController = TextEditingController();

  // Add: Reply state
  Map<String, dynamic>? _replyToMessage;

  /// Generates a consistent, canonical channel name for a private chat
  /// by sorting the user IDs. This ensures both users subscribe to the same channel.
  static String getPrivateChatChannelName(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'private-chat-${ids[0]}-${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData().then((_) {
      if (mounted) {
        _subscribeToMessages();
        _subscribeToContactStatus();
      }
    });
  }

  Future<void> _fetchInitialData() async {
    // Fetch profile and messages concurrently for faster loading.
    await Future.wait([_fetchContactProfile(), _fetchMessages()]);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _messagesSub.unsubscribe();
    _statusSub?.unsubscribe();
    super.dispose();
  }

  /// Mark a specific message as seen
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
      print('Error marking message as seen: $e');
    }
  }

  /// Mark all received messages in this chat as seen
  Future<void> _markReceivedMessagesAsSeen() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final contactId = widget.contact['id'];
      
      // Mark all messages from the contact as seen
      await Supabase.instance.client
          .from('messages')
          .update({
            'is_seen': true,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('sender_id', contactId)
          .eq('receiver_id', user.id)
          .eq('is_seen', false);
    } catch (e) {
      print('Error marking messages as seen: $e');
    }
  }

  void _subscribeToMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final contactId = widget.contact['id'];

    final channelName = getPrivateChatChannelName(user.id, contactId);

    // Subscribe to INSERT events for new messages
    _messagesSub = Supabase.instance.client.channel(channelName).on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'INSERT', schema: 'public', table: 'messages'),
      (payload, [ref]) {
        final newMessage = payload['new'] as Map<String, dynamic>;
        final isForThisChat =
            (newMessage['sender_id'] == user.id &&
                newMessage['receiver_id'] == contactId) ||
            (newMessage['sender_id'] == contactId &&
                newMessage['receiver_id'] == user.id);

        if (isForThisChat && mounted) {
          setState(() {
            // Prevent duplicates from race conditions
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
          
          // If this is a message received from the contact, mark it as seen
          if (newMessage['sender_id'] == contactId) {
            _markMessageAsSeen(newMessage['id']);
          }
        }
      },
    ).on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'UPDATE', schema: 'public', table: 'messages'),
      (payload, [ref]) {
        final updatedMessage = payload['new'] as Map<String, dynamic>;
        final isForThisChat =
            (updatedMessage['sender_id'] == user.id &&
                updatedMessage['receiver_id'] == contactId) ||
            (updatedMessage['sender_id'] == contactId &&
                updatedMessage['receiver_id'] == user.id);

        if (isForThisChat && mounted) {
          setState(() {
            final index = _messages.indexWhere((msg) => msg['id'] == updatedMessage['id']);
            if (index != -1) {
              _messages[index] = updatedMessage;
            }
          });
        }
      },
    );
    _messagesSub.subscribe((String status, [dynamic error]) {
      if (status == 'SUBSCRIBED') {
        print('Successfully subscribed to messages channel: $channelName');
      } else if (status == 'CHANNEL_ERROR' || status == 'CLOSED') {
        print('Error on messages channel ($channelName): $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Connection to chat lost. Please check your internet and restart the app.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
      final res = await Supabase.instance.client
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
    if (mounted) setState(() => _isLoading = true);
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
        
        // Mark received messages as seen
        _markReceivedMessagesAsSeen();
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
        'type': MessageType.text.name,
        'is_delivered': true, // Mark as delivered on send
        'is_seen': false, // Not seen yet
        if (_replyToMessage != null) 'reply_to_id': _replyToMessage!['id'],
      });
      setState(() {
        _replyToMessage = null;
      });
    } catch (e) {
      print('Error sending message: $e');
      _messageController.text = text; // Restore text on failure
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
    //  NO NEED [S]
    // if (diff.inHours < 48 && now.day - dt.day == 1) {
    //   return 'last seen yesterday at ${DateFormat('HH:mm').format(dt)}';
    // }
    return 'last seen on ${DateFormat('MMM dd').format(dt)}';
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
        builder: (context) => AlertDialog(
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

      final file = PlatformFile(
        name: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
        size: bytes.length,
        bytes: bytes,
      );

      setState(() => _sending = true);
      final url = await _uploadFileToSupabase(file, 'voices');
      if (mounted) setState(() => _sending = false);

      if (url != null) {
        await _sendMultimediaMessage(type: MessageType.voice.name, urls: [url]);
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

  Future<void> _sendMultimediaMessage({
    required String type,
    required List<String> urls,
    String? content,
  }) async {
    setState(() => _sending = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _sending = false);
      return;
    }
    final contactId = widget.contact['id'];
    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': contactId,
        'content': content,
        'type': type,
        'is_multimedia': true,
        'media_url': urls,
        'is_delivered': true, // Mark as delivered on send
        'is_seen': false, // Not seen yet
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

  // Add: Delete message logic
  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (message['sender_id'] != user.id) return;
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

  // Add: Edit message logic (text only)
  Future<void> _editMessage(
    Map<String, dynamic> message,
    String newText,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (message['sender_id'] != user.id) return;
    try {
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
                                isDelivered: msg['is_delivered'] ?? false, // NEW
                                isSeen: msg['is_seen'] ?? false, // NEW
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

/// A dedicated widget for displaying a single message bubble.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.onEdit,
    this.onDelete,
    this.onReply,
    this.onShowOptions,
    this.getMessageById,
    required this.isDelivered,
    required this.isSeen,
  });

  final Map<String, dynamic> message;
  final bool isMe;
  final void Function(Map<String, dynamic> message)? onEdit;
  final void Function(Map<String, dynamic> message)? onDelete;
  final void Function(Map<String, dynamic> message)? onReply;
  final void Function(Map<String, dynamic> message, bool isMe)? onShowOptions;
  final Map<String, dynamic>? Function(String id)? getMessageById;
  final bool isDelivered;
  final bool isSeen;

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
              if (isMe) // Only show status for messages sent by me
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

/// NEW WIDGET: Displays message delivery and seen status icons.
class _MessageStatusIcons extends StatelessWidget {
  const _MessageStatusIcons({
    required this.isDelivered,
    required this.isSeen,
    required this.color,
  });

  final bool isDelivered;
  final bool isSeen;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        // Show different icons based on status
        if (!isDelivered)
          // Not sent - show clock icon
          Icon(
            Icons.access_time,
            size: 16,
            color: color,
          )
        else if (isDelivered && !isSeen)
          // Delivered but not seen - show single checkmark like Telegram
          Icon(
            Icons.done,
            size: 16,
            color: color,
          )
        else if (isDelivered && isSeen)
          // Seen - show double checkmark with second one in blue
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.done_all,
                size: 16,
                color: const Color.fromARGB(255, 0, 0, 0), // Blue for seen status
              ),
            ],
          ),
      ],
    );
  }
}

/// WIDGET THAT IS NOW HEAVILY MODIFIED
class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.isMe});

  final Map<String, dynamic> message;
  final bool isMe;

  /// NEW: Helper method to trigger file download on web.
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
        return SizedBox(
          width: 200, // Fixed width for images
          height: 200, // Fixed height for images
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const CircularProgressIndicator(),
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.broken_image, color: textColor.withOpacity(0.8)),
            ),
          ),
        );

      // UPDATED: Voice messages now use the new player widget.
      case MessageType.voice:
        if (mediaUrl == null)
          return const Text('🎤 Voice message not available');
        return _VoiceMessagePlayer(mediaUrl: mediaUrl, isMe: isMe);

      // UPDATED: Other file types are now downloadable.
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
            // NEW: Download button
            IconButton(
              icon: Icon(Icons.download_rounded, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: mediaUrl == null
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

/// NEW WIDGET: A stateful widget to manage the audio player for a single voice message.
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
    final inactiveColor = widget.isMe
        ? Colors.white.withOpacity(0.7)
        : Colors.grey.shade400;

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

// Add the _EditMessageInput widget:
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
