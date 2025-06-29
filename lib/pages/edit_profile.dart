import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;

class EditProfile extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback? onUpdated;
  const EditProfile({this.profile, this.onUpdated, Key? key}) : super(key: key);

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late TextEditingController usernameController;
  late TextEditingController nameController;
  late TextEditingController bioController;
  String? avatarUrl;
  DateTime? birthday;
  XFile? avatarFile;
  Uint8List? avatarBytes;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(
      text: widget.profile?['username'] ?? '',
    );
    nameController = TextEditingController(text: widget.profile?['name'] ?? '');
    bioController = TextEditingController(text: widget.profile?['bio'] ?? '');
    avatarUrl = widget.profile?['avatar_url'];
    final bday = widget.profile?['birthday'];
    birthday =
        (bday != null && bday.toString().isNotEmpty)
            ? DateTime.tryParse(bday)
            : null;
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthday ?? now.subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        birthday = picked;
      });
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('username', username)
            .limit(1)
            .maybeSingle();
    final user = Supabase.instance.client.auth.currentUser;
    return res == null || res['id'] == user?.id;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        _showError('Avatar must be less than 2MB.');
        return;
      }
      if (kIsWeb) {
        setState(() {
          avatarFile = picked;
          avatarBytes = bytes;
        });
      } else {
        setState(() {
          avatarFile = picked;
        });
      }
    }
  }

  Future<String?> _uploadAvatar(XFile picked, String userId) async {
    final fileExt = picked.path.split('.').last;
    final fileName = 'avatar_$userId.$fileExt';
    final storage = Supabase.instance.client.storage.from('avatars');
    final bytes = await picked.readAsBytes();
    final res = await storage.uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    if (res.isNotEmpty) {
      final publicUrl = storage.getPublicUrl(fileName);
      return publicUrl;
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
    });
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('User not found. Please log in again.');
      setState(() {
        isLoading = false;
      });
      return;
    }
    final username = usernameController.text.trim();
    final isUnique = await _isUsernameUnique(username);
    if (!isUnique) {
      _showError('This username is already taken.');
      setState(() {
        isLoading = false;
      });
      return;
    }
    String? uploadedAvatarUrl = avatarUrl;
    if (avatarFile != null) {
      try {
        uploadedAvatarUrl = await _uploadAvatar(avatarFile!, user.id);
      } catch (e) {
        _showError('Failed to upload avatar.');
        setState(() {
          isLoading = false;
        });
        return;
      }
    }
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'username': username,
            'name': nameController.text.trim(),
            'avatar_url': uploadedAvatarUrl,
            'birthday': birthday != null ? birthday!.toIso8601String() : null,
            'bio': bioController.text.trim(),
          })
          .eq('id', user.id);
      if (widget.onUpdated != null) widget.onUpdated!();
      Navigator.of(context).pop();
    } catch (e) {
      _showError('Failed to save profile: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (avatarFile != null) {
      if (kIsWeb && avatarBytes != null) {
        avatarImage = MemoryImage(avatarBytes!);
      } else if (!kIsWeb) {
        avatarImage = FileImage(io.File(avatarFile!.path));
      }
    } else if (avatarUrl != null) {
      avatarImage = NetworkImage(avatarUrl!);
    }
    Widget avatarChild;
    if (avatarImage == null) {
      final initials =
          nameController.text.isNotEmpty
              ? nameController.text.trim().substring(0, 1).toUpperCase()
              : null;
      avatarChild =
          initials != null
              ? Text(
                initials,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
              : const Icon(Icons.camera_alt, color: Colors.white, size: 36);
    } else {
      avatarChild = const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar row with trash icon
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: isLoading ? null : _pickAvatar,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFF46C2CB),
                        backgroundImage: avatarImage,
                        child: avatarChild,
                      ),
                    ),
                    if (avatarImage != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Remove avatar',
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  setState(() {
                                    avatarFile = null;
                                    avatarBytes = null;
                                    avatarUrl = null;
                                  });
                                },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Color(0xFF6D5BFF),
                  ),
                  hintText: 'Full Name',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                    color: Color(0xFF6D5BFF),
                  ),
                  hintText: 'Username',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: isLoading ? null : _pickBirthday,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.cake,
                      color: Color(0xFF6D5BFF),
                    ),
                    hintText: 'Birthday',
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  child: Text(
                    birthday == null
                        ? 'Select your birthday (optional)'
                        : '${birthday!.year}/${birthday!.month.toString().padLeft(2, '0')}/${birthday!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: birthday == null ? Colors.grey : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bioController,
                maxLength: 100,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF6D5BFF),
                  ),
                  hintText: 'Bio (optional , 100 characters)',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 4,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.black26,
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => null,
                    ),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2.5,
                            ),
                          )
                          : Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
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
