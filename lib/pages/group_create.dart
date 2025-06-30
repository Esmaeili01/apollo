import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:math';
import 'group_chat.dart';

class GroupCreate extends StatefulWidget {
  const GroupCreate({super.key});

  @override
  State<GroupCreate> createState() => _GroupCreateState();
}

class _GroupCreateState extends State<GroupCreate> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  bool _isPublic = true;
  File? _avatarFile;
  bool _picking = false;
  String _randomLink = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateRandomLink();
  }

  void _generateRandomLink() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    _randomLink = List.generate(
      16,
      (index) => chars[random.nextInt(chars.length)],
    ).join('');
  }

  Future<String> _generateUniqueInviteLink() async {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    String link;
    bool isUnique = false;

    do {
      link = List.generate(
        16,
        (index) => chars[random.nextInt(chars.length)],
      ).join('');

      // Check if link already exists in database
      final existing =
          await Supabase.instance.client
              .from('groups')
              .select('id')
              .eq('invite_link', link)
              .maybeSingle();

      isUnique = existing == null;
    } while (!isUnique);

    return link;
  }

  Future<bool> _isInviteLinkUnique(String link) async {
    final existing =
        await Supabase.instance.client
            .from('groups')
            .select('id')
            .eq('invite_link', link)
            .maybeSingle();
    return existing == null;
  }

  Future<void> _pickAvatar() async {
    setState(() => _picking = true);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
      });
    }
    setState(() => _picking = false);
  }

  void _removeAvatar() {
    setState(() {
      _avatarFile = null;
    });
  }

  void _onGroupTypeChanged(bool isPublic) {
    setState(() {
      _isPublic = isPublic;
      if (!isPublic) {
        _generateRandomLink();
        // Check if the generated link exists in database
        _checkAndRegenerateLink();
      }
    });
  }

  Future<void> _checkAndRegenerateLink() async {
    if (!_isPublic) {
      bool isUnique = await _isInviteLinkUnique(_randomLink);
      if (!isUnique) {
        // If link exists, generate a new unique one
        _randomLink = await _generateUniqueInviteLink();
        setState(() {}); // Update UI with new link
      }
    }
  }

  Future<String?> _uploadAvatar(File avatarFile, String groupId) async {
    try {
      final fileExt = avatarFile.path.split('.').last;
      final fileName = 'group_avatar_$groupId.$fileExt';
      final storage = Supabase.instance.client.storage.from('avatars');

      final res = await storage.uploadBinary(
        fileName,
        await avatarFile.readAsBytes(),
        fileOptions: const FileOptions(upsert: true),
      );

      if (res.isNotEmpty) {
        final publicUrl = storage.getPublicUrl(fileName);
        return publicUrl;
      }
      return null;
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Upload avatar if selected
        String? avatarUrl;
        if (_avatarFile != null) {
          avatarUrl = await _uploadAvatar(
            _avatarFile!,
            'temp_${DateTime.now().millisecondsSinceEpoch}',
          );
        }

        // Generate unique invite link
        String inviteLink;
        if (_isPublic) {
          final customLink = _linkController.text.trim();
          if (await _isInviteLinkUnique(customLink)) {
            inviteLink = customLink;
          } else {
            throw Exception(
              'This invite link is already taken. Please choose a different one.',
            );
          }
        } else {
          inviteLink = await _generateUniqueInviteLink();
        }

        // Create group data object matching the database schema
        final groupData = {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'avatar_url': avatarUrl,
          'creator_id': user.id,
          'can_send_message': true,
          'can_send_media': true,
          'can_add_members': true,
          'can_pin_message': true,
          'can_change_info': true,
          'can_delete_message': false,
          'is_public': _isPublic,
          'invite_link': inviteLink,
        };

        // Insert group into database
        final groupResponse =
            await Supabase.instance.client
                .from('groups')
                .insert(groupData)
                .select()
                .single();

        print('Group created with ID: ${groupResponse['id']}');
        print('User ID: ${user.id}');

        // Add creator as first member
        try {
          final memberData = {
            'group_id': groupResponse['id'],
            'user_id': user.id,
            'role': 2, // 2 = owner
            'joined_at': DateTime.now().toIso8601String(),
          };

          print('Attempting to insert member data: $memberData');

          final memberResponse =
              await Supabase.instance.client
                  .from('group_members')
                  .insert(memberData)
                  .select();

          print('Creator added as member successfully: $memberResponse');
        } catch (e) {
          print('Error adding creator as member: $e');
          // Continue with navigation even if member addition fails
        }

        // Navigate to group chat page with the created group data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatPage(group: groupResponse),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_avatarFile != null) {
      avatarImage = FileImage(_avatarFile!);
    }

    Widget avatarChild;
    if (avatarImage == null) {
      avatarChild = const Icon(Icons.group, color: Colors.white, size: 48);
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
        title: const Text('New Group', style: TextStyle(color: Colors.white)),
        centerTitle: true,
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
                      if (_avatarFile != null)
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
                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Enter group name'
                              : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Group Bio (optional)',
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
                      onSelected: (v) => _onGroupTypeChanged(true),
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
                      onSelected: (v) => _onGroupTypeChanged(false),
                      selectedColor: const Color(0xFF46C2CB),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Group link section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Link:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isPublic)
                        TextFormField(
                          controller: _linkController,
                          decoration: InputDecoration(
                            hintText: 'Enter group link',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Enter group link'
                                      : null,
                        )
                      else
                        TextFormField(
                          controller: TextEditingController(text: _randomLink),
                          enabled: false,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: const Color(0xFF6D5BFF),
                    ),
                    onPressed: _createGroup,
                    child: const Text(
                      'Create Group',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
