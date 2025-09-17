import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'private_chat/private_chat.dart';

class UserProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;
  final bool fromPrivateChat; // Add flag to detect if coming from private chat
  
  const UserProfilePage({
    required this.profile, 
    this.fromPrivateChat = false,
    super.key
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isContact = false;
  bool _isBlocked = false;
  bool _notificationsEnabled = true;
  bool _isLoading = false; // Start with false to show buttons immediately
  bool _statusLoaded = false; // Track if status has been loaded

  @override
  void initState() {
    super.initState();
    _checkUserStatus(); // This now runs in background
  }

  Future<void> _checkUserStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _statusLoaded = true);
      return;
    }

    try {
      // Run both queries in parallel for faster loading
      final results = await Future.wait([
        // Check if user is in contacts
        Supabase.instance.client
            .from('contacts')
            .select('notifications_enabled')
            .eq('user_id', user.id)
            .eq('contact_id', widget.profile['id'])
            .maybeSingle(),
        
        // Check if user is blocked
        Supabase.instance.client
            .from('blocked_users')
            .select('*')
            .eq('blocker_id', user.id)
            .eq('blocked_id', widget.profile['id'])
            .maybeSingle(),
      ]);
      
      final contactRes = results[0];
      final blockedRes = results[1];
      
      // Update contact status
      if (contactRes != null) {
        _isContact = true;
        _notificationsEnabled = contactRes['notifications_enabled'] ?? true;
      }
      
      // Update blocked status
      if (blockedRes != null) {
        _isBlocked = true;
      }
      
      if (mounted) {
        setState(() => _statusLoaded = true);
      }
    } catch (e) {
      print('Error checking user status: $e');
      if (mounted) {
        setState(() => _statusLoaded = true);
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6D5BFF), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF6D5BFF),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6D5BFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMessageTap() async {
    // Check if user is authenticated before navigating
    final user = Supabase.instance.client.auth.currentUser;
    
    // Ensure we pass the correct contact data structure that PrivateChat expects
    final contactData = {
      'id': widget.profile['id'],
      'name': widget.profile['name'] ?? 'Unknown User',
      'bio': widget.profile['bio'] ?? '',
      'avatar_url': (widget.profile['avatar_url'] != null && widget.profile['avatar_url'].toString().isNotEmpty) 
          ? widget.profile['avatar_url'] 
          : null,
      'last_seen': widget.profile['last_seen'],
      'username': widget.profile['username'] ?? '',
    };
    
    print('=== DEBUG: Opening chat ===');
    print('Contact ID: ${contactData['id']}');
    print('Contact Name: ${contactData['name']}');
    print('Current User: ${user?.id ?? 'null'}');
    print('Profile data: ${widget.profile}');
    print('========================');
    
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to send messages'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Check if we have a valid contact ID
    if (contactData['id'] == null || contactData['id'].toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid user profile - cannot open chat'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      if (widget.fromPrivateChat) {
        // If coming from private chat, replace the entire navigation stack
        // This removes both the profile page and the previous chat page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => PrivateChat(contact: contactData),
          ),
          (route) => route.settings.name == '/home' || route.isFirst,
        );
      } else {
        // Normal navigation - just push the chat page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrivateChat(contact: contactData),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onAddContact() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('contacts').insert({
        'user_id': user.id,
        'contact_id': widget.profile['id'],
        'nickname': widget.profile['name'],
        'notifications_enabled': true,
      });

      setState(() {
        _isContact = true;
        _notificationsEnabled = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onToggleNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final newValue = !_notificationsEnabled;
      await Supabase.instance.client
          .from('contacts')
          .update({'notifications_enabled': newValue})
          .eq('user_id', user.id)
          .eq('contact_id', widget.profile['id']);

      setState(() {
        _notificationsEnabled = newValue;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? 'Notifications enabled'
                  : 'Notifications disabled',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onToggleBlock() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      if (_isBlocked) {
        // Unblock user
        await Supabase.instance.client
            .from('blocked_users')
            .delete()
            .eq('blocker_id', user.id)
            .eq('blocked_id', widget.profile['id']);

        setState(() {
          _isBlocked = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User unblocked'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        // Block user
        await Supabase.instance.client.from('blocked_users').insert({
          'blocker_id': user.id,
          'blocked_id': widget.profile['id'],
        });

        setState(() {
          _isBlocked = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User blocked'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isBlocked ? 'unblock' : 'block'} user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'Unknown';
    final dt = DateTime.tryParse(lastSeen.toString());
    if (dt == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 2) {
      return 'yesterday at ${DateFormat('HH:mm').format(dt)}';
    } else {
      return '${diff.inDays} days ago at ${DateFormat('dd MMM, HH:mm').format(dt)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.profile['avatar_url'] as String?;
    final name = widget.profile['name'] as String? ?? '';
    final username = widget.profile['username'] as String? ?? '';
    final bio = widget.profile['bio'] as String? ?? '';
    final lastSeen = widget.profile['last_seen'];
    final birthday = widget.profile['birthday'];
    final bool isContact = widget.profile['is_contact'] == true;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                margin: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                child: Stack(
                  children: [
                    // Return button at upper left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black54,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                          ? () {
                                            Navigator.of(context).push(
                                              PageRouteBuilder(
                                                opaque: false,
                                                barrierColor: Colors.black,
                                                pageBuilder: (context, _, __) {
                                                  return _AvatarFullScreen(
                                                    avatarUrl: avatarUrl,
                                                    tag:
                                                        'profile_avatar_$avatarUrl',
                                                  );
                                                },
                                              ),
                                            );
                                          }
                                          : null,
                                  child: Hero(
                                    tag: 'profile_avatar_$avatarUrl',
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: const Color(0xFF46C2CB),
                                      backgroundImage:
                                          avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                      child:
                                          (avatarUrl == null ||
                                                  avatarUrl.isEmpty)
                                              ? Text(
                                                name.isNotEmpty
                                                    ? name
                                                        .substring(0, 1)
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 32,
                                                ),
                                              )
                                              : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                                if (lastSeen != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _formatLastSeen(lastSeen),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Action buttons row - show immediately with default states
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                icon: Icons.message,
                                label: 'Message',
                                onTap: _onMessageTap,
                              ),
                              _isContact
                                  ? _buildActionButton(
                                      icon: _notificationsEnabled
                                          ? Icons.notifications
                                          : Icons.notifications_off,
                                      label: _notificationsEnabled
                                          ? 'Mute'
                                          : 'Unmute',
                                      onTap: _onToggleNotifications,
                                    )
                                  : _buildActionButton(
                                      icon: Icons.person_add,
                                      label: 'Add contact',
                                      onTap: _onAddContact,
                                    ),
                              _buildActionButton(
                                icon: _isBlocked ? Icons.person : Icons.block,
                                label: _isBlocked ? 'Unblock' : 'Block',
                                onTap: _onToggleBlock,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (username.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Username',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    username,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (bio.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    bio,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (birthday != null &&
                              birthday.toString().isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Birthday',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    birthday.toString().substring(0, 10),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Menu button at upper right corner of the card
                    Positioned(
                        top: 8,
                        right: 8,
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.black54,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'block',
                              child: Text(_isBlocked ? 'Unblock user' : 'Block user'),
                            ),
                            if (_isContact) ...[
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete contact'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit contact'),
                              ),
                            ] else ...[
                              const PopupMenuItem(
                                value: 'add',
                                child: Text('Add to contact'),
                              ),
                            ],
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'block':
                                _onToggleBlock();
                                break;
                              case 'add':
                                _onAddContact();
                                break;
                              case 'delete':
                                // Handle delete contact
                                break;
                              case 'edit':
                                // Handle edit contact
                                break;
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarFullScreen extends StatelessWidget {
  final String avatarUrl;
  final String tag;
  const _AvatarFullScreen({required this.avatarUrl, required this.tag});

  @override
  Widget build(BuildContext context) {
    // Get the user's name from the previous route's arguments if available
    final ModalRoute? parentRoute = ModalRoute.of(context);
    String? userName;
    if (parentRoute != null && parentRoute.settings.arguments is Map) {
      final args = parentRoute.settings.arguments as Map;
      userName = args['name'] as String?;
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: tag,
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(avatarUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          // AppBar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 56,
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.1),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                    ),
                    Center(
                      child: Text(
                        userName ?? '',
                        style: const TextStyle(
                          color: Colors.white, // Ensure the name is white
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        tooltip: 'Download',
                        onPressed: () {
                          // Download logic here
                          // You can use a package like 'image_downloader' or 'gallery_saver' for actual download
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
