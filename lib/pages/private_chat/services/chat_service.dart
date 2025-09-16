import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_type.dart';

class ChatService {
  static String getPrivateChatChannelName(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'private-chat-${ids[0]}-${ids[1]}';
  }

  static Future<void> markMessageAsSeen(String messageId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'is_seen': true,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId);
    } catch (e) {
      // Handle error silently
    }
  }

  static Future<void> markReceivedMessagesAsSeen(String contactId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
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
      // Handle error silently
    }
  }

  static Future<void> sendMessage({
    required String receiverId,
    required String content,
    String? replyToId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('messages').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'content': content,
      'type': MessageType.text.name,
      'is_delivered': true,
      'is_seen': false,
      if (replyToId != null) 'reply_to_id': replyToId,
    });
  }

  static Future<void> sendMultimediaMessage({
    required String receiverId,
    required String type,
    required List<String> urls,
    String? content,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('messages').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'content': content,
      'type': type,
      'is_multimedia': true,
      'media_url': urls,
      'is_delivered': true,
      'is_seen': false,
    });
  }

  static Future<void> deleteMessage(String messageId, String senderId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || senderId != user.id) return;
    await Supabase.instance.client
        .from('messages')
        .delete()
        .eq('id', messageId);
  }

  static Future<void> editMessage(
    String messageId,
    String senderId,
    String newContent,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || senderId != user.id) return;
    await Supabase.instance.client
        .from('messages')
        .update({'content': newContent})
        .eq('id', messageId);
  }

  static Future<List<Map<String, dynamic>>> fetchMessages(String contactId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    
    final messages = await Supabase.instance.client
        .from('messages')
        .select()
        .or(
          'and(sender_id.eq.${user.id},receiver_id.eq.$contactId),and(sender_id.eq.$contactId,receiver_id.eq.${user.id})',
        )
        .order('created_at', ascending: true);
    
    return List<Map<String, dynamic>>.from(messages);
  }

  static Future<Map<String, dynamic>?> fetchContactProfile(String contactId) async {
    try {
      return await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', contactId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  static Future<void> loadNotificationSetting(String contactId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('contacts')
          .select('notifications_enabled')
          .eq('user_id', userId)
          .eq('contact_id', contactId)
          .maybeSingle();
    } catch (e) {
      // Handle error silently
    }
  }

  static Future<void> toggleNotification(String contactId, bool newValue) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('contacts')
          .update({'notifications_enabled': newValue})
          .eq('user_id', userId)
          .eq('contact_id', contactId);
    } catch (e) {
      // Handle error silently
    }
  }
}