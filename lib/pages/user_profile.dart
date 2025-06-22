import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserProfilePage extends StatelessWidget {
  final Map<String, dynamic> profile;
  const UserProfilePage({required this.profile, super.key});

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
    final avatarUrl = profile['avatar_url'] as String?;
    final name = profile['name'] as String? ?? '';
    final username = profile['username'] as String? ?? '';
    final bio = profile['bio'] as String? ?? '';
    final lastSeen = profile['last_seen'];
    final birthday = profile['birthday'];
    final bool isContact = profile['is_contact'] == true;
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
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'block',
                                child: Text('Block user'),
                              ),
                              if (isContact) ...[
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
                          // Handle menu actions here
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
