import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupProfilePage extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupProfilePage({required this.group, super.key});

  @override
  State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
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
              bio,
              last_seen
            )
          ''')
          .eq('group_id', widget.group['id']);

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
                'last_seen': profile['last_seen'],
              };
            }).toList();
      });
    } catch (e) {
      setState(() {
        _members = [];
      });
    } finally {
      setState(() => _isLoading = false);
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
    final avatarUrl = widget.group['avatar_url'] as String?;
    final name = widget.group['name'] as String? ?? 'Group';
    final bio = widget.group['bio'] as String? ?? '';
    final isPublic = widget.group['is_public'] == true;
    final creatorId = widget.group['creator_id'] as String?;

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
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
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
                                          avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? () {
                                                Navigator.of(context).push(
                                                  PageRouteBuilder(
                                                    opaque: false,
                                                    barrierColor: Colors.black,
                                                    pageBuilder: (
                                                      context,
                                                      _,
                                                      __,
                                                    ) {
                                                      return _AvatarFullScreen(
                                                        avatarUrl: avatarUrl,
                                                        tag:
                                                            'group_avatar_$avatarUrl',
                                                      );
                                                    },
                                                  ),
                                                );
                                              }
                                              : null,
                                      child: Hero(
                                        tag: 'group_avatar_$avatarUrl',
                                        child: CircleAvatar(
                                          radius: 48,
                                          backgroundColor: const Color(
                                            0xFF46C2CB,
                                          ),
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${_members.length} members',
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
                                      'Type',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isPublic
                                          ? 'Public Group'
                                          : 'Private Group',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Description',
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
                                    value: 'edit',
                                    child: Text('Edit group'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'invite',
                                    child: Text('Invite members'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'leave',
                                    child: Text('Leave group'),
                                  ),
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
              // Member list below the card
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isLoading && _members.isNotEmpty)
                Container(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Members',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Add Member button
                            GestureDetector(
                              onTap: () async {
                                // Show modal with selectable contacts
                                await showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return _AddMemberSheet(
                                      groupId: widget.group['id'],
                                      currentMemberIds:
                                          _members
                                              .map(
                                                (m) => m['user_id'] as String,
                                              )
                                              .toList(),
                                      onMemberAdded: () async {
                                        Navigator.of(context).pop();
                                        await _fetchMembers();
                                      },
                                    );
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D5BFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.person_add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Add Member',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ..._members.map(
                              (m) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFF46C2CB),
                                      backgroundImage:
                                          m['avatar_url'] != null &&
                                                  m['avatar_url'].isNotEmpty
                                              ? NetworkImage(m['avatar_url'])
                                              : null,
                                      child:
                                          (m['avatar_url'] == null ||
                                                  m['avatar_url'].isEmpty)
                                              ? Text(
                                                (m['name'] ?? '?')
                                                    .toString()
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                              : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m['name'] ?? '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (m['last_seen'] != null)
                                            Text(
                                              _formatLastSeen(m['last_seen']),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (m['role_text'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Text(
                                          m['role_text'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
    // Get the group name from the previous route's arguments if available
    final ModalRoute? parentRoute = ModalRoute.of(context);
    String? groupName;
    if (parentRoute != null && parentRoute.settings.arguments is Map) {
      final args = parentRoute.settings.arguments as Map;
      groupName = args['name'] as String?;
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
                        groupName ?? '',
                        style: const TextStyle(
                          color: Colors.white,
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

class _AddMemberSheet extends StatefulWidget {
  final String groupId;
  final List<String> currentMemberIds;
  final VoidCallback onMemberAdded;
  const _AddMemberSheet({
    required this.groupId,
    required this.currentMemberIds,
    required this.onMemberAdded,
  });

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String? _error;
  Set<String> _selectedIds = {};
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final res = await Supabase.instance.client
          .from('contacts')
          .select()
          .eq('user_id', user.id);
      final contacts = List<Map<String, dynamic>>.from(res as List);
      List<Map<String, dynamic>> contactsWithProfiles = [];
      for (final contact in contacts) {
        final profileRes =
            await Supabase.instance.client
                .from('profiles')
                .select('id, name, bio, avatar_url, last_seen')
                .eq('id', contact['contact_id'])
                .maybeSingle();
        if (profileRes != null &&
            !widget.currentMemberIds.contains(profileRes['id'])) {
          contactsWithProfiles.add(profileRes);
        }
      }
      setState(() {
        _contacts = contactsWithProfiles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _contacts = [];
        _loading = false;
        _error = 'Failed to load contacts';
      });
    }
  }

  Future<void> _addSelectedToGroup() async {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _adding = true;
    });
    try {
      final toAdd =
          _contacts.where((c) => _selectedIds.contains(c['id'])).toList();
      for (final contact in toAdd) {
        // Prevent duplicate membership
        final existing =
            await Supabase.instance.client
                .from('group_members')
                .select()
                .eq('group_id', widget.groupId)
                .eq('user_id', contact['id'])
                .maybeSingle();
        if (existing == null) {
          try {
            final data = {
              'group_id': widget.groupId,
              'user_id': contact['id'],
              'role': 0,
              'joined_at': DateTime.now().toIso8601String(),
            };
            print('Inserting into group_members: ' + data.toString());
            await Supabase.instance.client.from('group_members').insert(data);
          } catch (e) {
            print(
              'Insert failed for contact: ' +
                  contact['id'].toString() +
                  ' error: ' +
                  e.toString(),
            );
            setState(() {
              _error =
                  'Insert failed for ${contact['name'] ?? contact['id']}: ${e.toString()}';
            });
          }
        }
      }
      widget.onMemberAdded();
    } catch (e) {
      print('General add member error: ' + e.toString());
      setState(() {
        _error = 'Failed to add member(s): ${e.toString()}';
      });
    } finally {
      setState(() {
        _adding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select contacts to add',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (_selectedIds.isNotEmpty)
                  TextButton(
                    onPressed: _adding ? null : _addSelectedToGroup,
                    child:
                        _adding
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Add Selected'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (!_loading && _contacts.isEmpty)
              const Text('No contacts available to add.'),
            if (!_loading && _contacts.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = _contacts[i];
                    final avatarUrl = c['avatar_url'] as String?;
                    final name = c['name'] as String? ?? '';
                    final bio = c['bio'] as String? ?? '';
                    final id = c['id'] as String;
                    final selected = _selectedIds.contains(id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF46C2CB),
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                        child:
                            avatarUrl == null || avatarUrl.isEmpty
                                ? Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          bio.isNotEmpty
                              ? Text(
                                bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                              : null,
                      trailing: Checkbox(
                        value: selected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedIds.remove(id);
                          } else {
                            _selectedIds.add(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
