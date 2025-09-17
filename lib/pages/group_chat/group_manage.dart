import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../home.dart';

class GroupManagePage extends StatefulWidget {
  final Map<String, dynamic> group;
  final int currentUserRole; // 0: Member, 1: Admin, 2: Owner

  const GroupManagePage({
    required this.group,
    required this.currentUserRole,
    super.key,
  });

  @override
  State<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isPublic = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _ownersAndAdmins = [];
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  bool _picking = false;
  RealtimeChannel? _groupSub;
  Map<String, dynamic> _groupData = {};
  
  // Permission settings for simple members
  bool _canSendMessage = true;
  bool _canSendMedia = true;
  bool _canAddMembers = true;
  
  @override
  void initState() {
    super.initState();
    _groupData = Map<String, dynamic>.from(widget.group);
    _initializeData();
    _fetchOwnersAndAdmins();
    _subscribeToGroupUpdates();
  }

  void _initializeData() {
    _nameController.text = widget.group['name'] ?? '';
    _bioController.text = widget.group['bio'] ?? '';
    _isPublic = widget.group['is_public'] ?? false;
    _canSendMessage = widget.group['can_send_message'] ?? true;
    _canSendMedia = widget.group['can_send_media'] ?? true;
    _canAddMembers = widget.group['can_add_members'] ?? true;
  }

  Future<void> _fetchOwnersAndAdmins() async {
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
          .eq('group_id', widget.group['id'])
          .gte('role', 1); // Only get admins (1) and owners (2)

      setState(() {
        _ownersAndAdmins = (response as List).map((member) {
          final profile = member['profiles'] as Map<String, dynamic>;
          final role = member['role'] as int? ?? 0;
          String roleText = '';
          switch (role) {
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
        _ownersAndAdmins = [];
      });
    }
  }

  Future<void> _pickAvatar() async {
    setState(() => _picking = true);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar must be less than 2MB.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _picking = false);
        return;
      }
      if (kIsWeb) {
        setState(() {
          _avatarFile = picked;
          _avatarBytes = bytes;
        });
      } else {
        setState(() {
          _avatarFile = picked;
        });
      }
    }
    setState(() => _picking = false);
  }

  void _removeAvatar() {
    setState(() {
      _avatarFile = null;
    });
  }

  Future<String?> _uploadAvatar(XFile picked, String groupId) async {
    try {
      print('Starting avatar upload for group: $groupId');
      final fileExt = picked.path.split('.').last;
      final fileName = 'group_avatar_$groupId.$fileExt';
      print('Upload filename: $fileName');
      
      final storage = Supabase.instance.client.storage.from('avatars');
      final bytes = await picked.readAsBytes();
      
      print('Uploading file...');
      final res = await storage.uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      
      print('File uploaded successfully');
      final publicUrl = storage.getPublicUrl(fileName);
      print('Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Error uploading avatar: $e');
      print('Error type: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> _updateGroupInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Upload avatar if selected
      String? avatarUrl = widget.group['avatar_url'];
      if (_avatarFile != null) {
        try {
          avatarUrl = await _uploadAvatar(_avatarFile!, widget.group['id']);
          if (avatarUrl == null) {
            throw Exception('Failed to upload avatar');
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload avatar: $e'),
              backgroundColor: Colors.orange,
            ),
          );
          // Keep the old avatar URL if upload fails
          avatarUrl = widget.group['avatar_url'];
        }
      }

      await Supabase.instance.client
          .from('groups')
          .update({
            'name': _nameController.text.trim(),
            'bio': _bioController.text.trim(),
            'is_public': _isPublic,
            'avatar_url': avatarUrl,
            'can_send_message': _canSendMessage,
            'can_send_media': _canSendMedia,
            'can_add_members': _canAddMembers,
          })
          .eq('id', widget.group['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group updated successfully')),
      );
      
      // Create updated group data to pass back
      final updatedGroup = Map<String, dynamic>.from(_groupData);
      updatedGroup.addAll({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'is_public': _isPublic,
        'avatar_url': avatarUrl,
        'can_send_message': _canSendMessage,
        'can_send_media': _canSendMedia,
        'can_add_members': _canAddMembers,
      });
      
      // Update our local group data too
      _groupData = updatedGroup;
      
      Navigator.pop(context, updatedGroup); // Return updated group data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update group: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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
      await _fetchOwnersAndAdmins();
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
      await _fetchOwnersAndAdmins();
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
    
    // Owners can manage all, Admins can manage members only
    final canManage = widget.currentUserRole == 2 || 
                     (widget.currentUserRole == 1 && memberRole == 0);
    
    if (isCurrentUser || !canManage) return;

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
            if (widget.currentUserRole == 2 || memberRole == 0) ...[
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(memberRole == 1 ? 'Remove Admin' : 'Make Admin'),
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

  void _showDeleteGroupConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      // Delete group messages first (messages table references group_id)
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('group_id', widget.group['id']);

      // Delete group members second (group_members table references group_id)
      await Supabase.instance.client
          .from('group_members')
          .delete()
          .eq('group_id', widget.group['id']);

      // Delete the group last (parent table)
      await Supabase.instance.client
          .from('groups')
          .delete()
          .eq('id', widget.group['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
        );
        
        // Navigate to home page after deletion
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_avatarFile != null) {
      if (kIsWeb && _avatarBytes != null) {
        avatarImage = MemoryImage(_avatarBytes!);
      } else if (!kIsWeb) {
        avatarImage = FileImage(File(_avatarFile!.path));
      }
    } else if (widget.group['avatar_url'] != null && widget.group['avatar_url'].isNotEmpty) {
      avatarImage = NetworkImage(widget.group['avatar_url']);
    }

    Widget avatarChild;
    if (avatarImage == null) {
      final name = widget.group['name'] ?? 'Group';
      avatarChild = Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      avatarChild = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manage Group', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _updateGroupInfo,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF5F6FA),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar row with trash icon
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _picking ? null : _pickAvatar,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF46C2CB),
                          backgroundImage: avatarImage,
                          child: avatarChild,
                        ),
                      ),
                      if (_avatarFile != null || widget.group['avatar_url'] != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Remove avatar',
                          onPressed: _removeAvatar,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter group name' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Group Bio',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Group Type:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Public'),
                          if (_isPublic) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.public, size: 16),
                          ],
                        ],
                      ),
                      selected: _isPublic,
                      onSelected: (v) => setState(() => _isPublic = true),
                      selectedColor: const Color(0xFF46C2CB),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Private'),
                          if (!_isPublic) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock, size: 16),
                          ],
                        ],
                      ),
                      selected: !_isPublic,
                      onSelected: (v) => setState(() => _isPublic = false),
                      selectedColor: const Color(0xFF46C2CB),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Member Permissions Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Member Permissions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Can Send Messages'),
                        subtitle: const Text('Allow members to send text messages'),
                        value: _canSendMessage,
                        onChanged: (value) => setState(() => _canSendMessage = value),
                        activeColor: const Color(0xFF46C2CB),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Can Send Media'),
                        subtitle: const Text('Allow members to send photos, videos, voice, and files'),
                        value: _canSendMedia,
                        onChanged: (value) => setState(() => _canSendMedia = value),
                        activeColor: const Color(0xFF46C2CB),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Can Add Members'),
                        subtitle: const Text('Allow members to add new people to the group'),
                        value: _canAddMembers,
                        onChanged: (value) => setState(() => _canAddMembers = value),
                        activeColor: const Color(0xFF46C2CB),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Owners and Admins Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Owners & Admins',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_ownersAndAdmins.length} people',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _ownersAndAdmins.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final member = _ownersAndAdmins[index];
                          final avatarUrl = member['avatar_url'] as String?;
                          final name = member['name'] ?? 'Unknown';
                          final roleText = member['role_text'] ?? '';
                          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                          final isCurrentUser = member['user_id'] == currentUserId;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF46C2CB),
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(roleText),
                            trailing: isCurrentUser
                                ? const Text('You', style: TextStyle(color: Color(0xFF6D5BFF), fontWeight: FontWeight.w600))
                                : (widget.currentUserRole == 2 && member['role'] == 1)
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _demoteAdmin(member),
                                        tooltip: 'Demote to Member',
                                      )
                                    : null,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Danger Zone (Only for Owner)
                if (widget.currentUserRole == 2) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: const Icon(Icons.delete_forever, color: Colors.red),
                          title: const Text(
                            'Delete Group',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                          ),
                          subtitle: const Text(
                            'Permanently delete this group and all its data',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: _showDeleteGroupConfirmation,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _demoteAdmin(Map<String, dynamic> member) async {
    final memberName = member['name'] as String? ?? 'Unknown';
    final userId = member['user_id'] as String;
    
    print('Demoting admin: $memberName ($userId)');
    
    try {
      // Update role to 0 (Member) in database
      await Supabase.instance.client
          .from('group_members')
          .update({'role': 0})
          .eq('group_id', widget.group['id'])
          .eq('user_id', userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$memberName demoted to Member'),
            backgroundColor: Colors.orange,
          ),
        );
        await _fetchOwnersAndAdmins(); // Refresh the list
      }
    } catch (e) {
      print('Failed to demote admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to demote $memberName'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _subscribeToGroupUpdates() {
    if (widget.group['id'] == null) return;
    
    final channelName = 'group-updates-${widget.group['id']}';
    _groupSub = Supabase.instance.client.channel(channelName)
      ..on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: 'UPDATE', schema: 'public', table: 'groups'),
        (payload, [ref]) {
          final updatedGroup = payload['new'] as Map<String, dynamic>;
          if (updatedGroup['id'] == widget.group['id'] && mounted) {
            setState(() {
              // Update local group data
              _groupData.addAll(updatedGroup);
              // Update form fields with new data
              _nameController.text = updatedGroup['name'] ?? _nameController.text;
              _bioController.text = updatedGroup['bio'] ?? _bioController.text;
              _isPublic = updatedGroup['is_public'] ?? _isPublic;
              _canSendMessage = updatedGroup['can_send_message'] ?? _canSendMessage;
              _canSendMedia = updatedGroup['can_send_media'] ?? _canSendMedia;
              _canAddMembers = updatedGroup['can_add_members'] ?? _canAddMembers;
            });
          }
        },
      );
    _groupSub?.subscribe();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _groupSub?.unsubscribe();
    super.dispose();
  }
}