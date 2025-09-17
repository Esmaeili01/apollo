import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  bool _picking = false;
  String _randomLink = '';
  String? _avatarFileExtension;

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

  Future<void> _createGroup() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
      });

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Generate unique invite link first
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

        // Create group data object without avatar first
        final groupData = {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'creator_id': user.id,
          'can_send_message': true,
          'can_send_media': true,
          'can_add_members': true,
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

        // Upload avatar after group creation if selected
        String? avatarUrl;
        if (_avatarFile != null) {
          try {
            avatarUrl = await _uploadAvatar(_avatarFile!, groupResponse['id']);
            
            // Update group with avatar URL
            if (avatarUrl != null) {
              await Supabase.instance.client
                  .from('groups')
                  .update({'avatar_url': avatarUrl})
                  .eq('id', groupResponse['id']);
              
              // Update the response object with the avatar URL
              groupResponse['avatar_url'] = avatarUrl;
            }
          } catch (e) {
            print('Failed to upload avatar, but group created: $e');
            // Continue with group creation even if avatar upload fails
          }
        }

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
        });
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
