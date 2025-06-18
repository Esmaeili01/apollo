import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
// Only import dart:io if not web
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' as io;

class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  DateTime? birthday;
  String? avatarUrl;
  XFile? avatarFile;
  Uint8List? avatarBytes;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 365 * 18)),
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
    // Allow if no user found or the only user is the current user
    return res == null || res['id'] == user?.id;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      // Validate file size (max 2MB)
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

    // On web, always use bytes
    final bytes = await picked.readAsBytes();

    final res = await storage.uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    print('Upload response: $res');
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
    // Username uniqueness check
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
        print('Avatar upload error: $e');
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
            'avatar_url': uploadedAvatarUrl,
            'birthday': birthday?.toIso8601String(),
            'bio': bioController.text.trim(),
          })
          .eq('id', user.id);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showError('Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
    // Avatar placeholder: show initials if username entered, else default icon
    Widget avatarChild;
    if (avatarImage == null) {
      final initials =
          (usernameController.text.isNotEmpty)
              ? usernameController.text.trim().substring(0, 1).toUpperCase()
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
        backgroundColor: const Color(0xFF6D5BFF),
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 0,
      ),
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
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6D5BFF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: isLoading ? null : _pickAvatar,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFF46C2CB),
                            backgroundImage: avatarImage,
                            child: avatarChild,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.person,
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
                        const SizedBox(height: 16),
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
                                color:
                                    birthday == null
                                        ? Colors.grey
                                        : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                            hintText: 'Bio (max 100 chars)',
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
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color?>(
                                    (states) => null,
                                  ),
                            ),
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                    : Ink(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6D5BFF),
                                            Color(0xFF46C2CB),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Save & Continue',
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
