import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'group_manage.dart';
import '../user_profile.dart';

class GroupProfilePage extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupProfilePage({required this.group, super.key});

  @override
  State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  int _currentUserRole = 0; // 0: Member, 1: Admin, 2: Owner

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

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      int userRole = 0;

      setState(() {
        _members = (response as List).map((member) {
          final profile = member['profiles'] as Map<String, dynamic>;
          final role = member['role'] as int? ?? 0;
          
          // Check if this is the current user to get their role
          if (member['user_id'] == currentUserId) {
            userRole = role;
          }
          
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
        _currentUserRole = userRole;
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

  Future<void> _removeMember(String userId) async {
    try {
      await Supabase.instance.client
          .from('group_members')
          .delete()
          .eq('group_id', widget.group['id'])
          .eq('user_id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed successfully')),
      );
      await _fetchMembers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove member: $e')),
      );
    }
  }

  Future<void> _changeRole(String userId, int newRole) async {
    try {
      await Supabase.instance.client
          .from('group_members')
          .update({'role': newRole})
          .eq('group_id', widget.group['id'])
          .eq('user_id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role updated successfully')),
      );
      await _fetchMembers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: $e')),
      );
    }
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCurrentUser = member['user_id'] == currentUserId;
    final memberRole = member['role'] as int;
    
    // Only owners and admins can manage members
    if (_currentUserRole < 1 || isCurrentUser) return;
    
    // Owners can manage all, Admins can only manage regular members
    final canManage = _currentUserRole == 2 || 
                     (_currentUserRole == 1 && memberRole == 0);
    
    if (!canManage) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                member['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_currentUserRole == 2 || memberRole == 0) ...[
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(memberRole == 1 ? 'Remove Admin' : 'Promote to Admin'),
                onTap: () {
                  Navigator.pop(context);
                  _changeRole(member['user_id'], memberRole == 1 ? 0 : 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('Remove from Group', 
                                style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveConfirmation(member);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRemoveConfirmation(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member['name']} from the group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member['user_id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.group['avatar_url'] as String?;
    final name = widget.group['name'] as String? ?? 'Group';
    final bio = widget.group['bio'] as String? ?? '';
    final isPublic = widget.group['is_public'] == true;
    final creatorId = widget.group['creator_id'] as String?;
    final inviteLink = widget.group['invite_link'] as String?;

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
                                                  pageBuilder: (context, _, __) {
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
                              // Only show for public groups
                              if (isPublic)
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
                                        'Public Group',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        inviteLink != null && inviteLink.isNotEmpty
                                            ? '@$inviteLink'
                                            : '@no_invite_link',
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
                        // Management button at upper right corner of the card
                        if (_currentUserRole >= 1)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.black54,
                              ),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GroupManagePage(
                                      group: widget.group,
                                      currentUserRole: _currentUserRole,
                                    ),
                                  ),
                                );
                                // If changes were made, refresh the data
                                if (result == true) {
                                  await _fetchMembers();
                                }
                              },
                              tooltip: 'Manage Group',
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
                            // Add Member button (full width)
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
                                      currentMemberIds: _members
                                          .map((m) => m['user_id'] as String)
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
                                width: double.infinity, // Full width
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D5BFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.person_add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add Member',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ..._members.map(
                              (m) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    // Navigate to user profile
                                    final profileData = {
                                      'id': m['user_id'],
                                      'name': m['name'],
                                      'username': m['username'],
                                      'avatar_url': m['avatar_url'],
                                      'bio': m['bio'],
                                      'last_seen': m['last_seen'],
                                      'is_contact': false, // We don't have this info in group context
                                    };
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UserProfilePage(
                                          profile: profileData,
                                        ),
                                      ),
                                    );
                                  },
                                  onLongPress: () {
                                    // Show context menu for owners and admins only
                                    if (_currentUserRole >= 1) {
                                      _showMemberOptions(m);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                      horizontal: 4.0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
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
                                        // Only show role badge for admins (1) and owners (2), not members (0)
                                        if (m['role_text'] != null && m['role'] > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8.0,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: m['role'] == 2 
                                                    ? Colors.orange.shade100
                                                    : Colors.blue.shade100, // Only admin or owner
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                m['role_text'],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: m['role'] == 2 
                                                      ? Colors.orange.shade700
                                                      : Colors.blue.shade700, // Only admin or owner
                                                  fontWeight: FontWeight.w600,
                                                ),
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
        final profileRes = await Supabase.instance.client
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
      final toAdd = _contacts
          .where((c) => _selectedIds.contains(c['id']))
          .toList();
      for (final contact in toAdd) {
        // Prevent duplicate membership
        final existing = await Supabase.instance.client
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
                    child: _adding
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
                        child: avatarUrl == null || avatarUrl.isEmpty
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
                      subtitle: bio.isNotEmpty
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
