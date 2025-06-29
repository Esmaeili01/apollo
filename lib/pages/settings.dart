import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'edit_profile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _showEditProfile(BuildContext context, Map<String, dynamic> profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditProfile(
              profile: profile,
              onUpdated: () {
                setState(() {}); // Refresh profile after editing
              },
            ),
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
    if (res == null) return null;
    res['email'] = user.email;
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar, but add a back button at the top left
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
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _fetchProfile(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const Center(
                              child: Text('Failed to load profile'),
                            );
                          }
                          final profile = snapshot.data!;
                          final avatarUrl = profile['avatar_url'] as String?;
                          final name = profile['name'] as String? ?? '';
                          final username = profile['username'] as String? ?? '';
                          final email = profile['email'] as String? ?? '';
                          final birthday = profile['birthday'] as String?;
                          final bio = profile['bio'] as String? ?? '';
                          ImageProvider? avatarImage;
                          if (avatarUrl != null && avatarUrl.isNotEmpty) {
                            avatarImage = NetworkImage(avatarUrl);
                          }
                          Widget avatarChild;
                          if (avatarImage == null) {
                            final initials =
                                name.isNotEmpty
                                    ? name.trim().substring(0, 1).toUpperCase()
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
                                    : const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 40,
                                    );
                          } else {
                            avatarChild = const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Center(
                                        child: CircleAvatar(
                                          radius: 40,
                                          backgroundColor: const Color(
                                            0xFF46C2CB,
                                          ),
                                          backgroundImage: avatarImage,
                                          child: avatarChild,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border.all(
                                            color: Color(0xFF6D5BFF),
                                            width: 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Username',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              username.isNotEmpty
                                                  ? username
                                                  : '-',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border.all(
                                            color: Color(0xFF6D5BFF),
                                            width: 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Email',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              email.isNotEmpty ? email : '-',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border.all(
                                            color: Color(0xFF6D5BFF),
                                            width: 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Birthday',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              birthday != null &&
                                                      birthday.isNotEmpty
                                                  ? DateFormat(
                                                    'yyyy-MM-dd',
                                                  ).format(
                                                    DateTime.parse(birthday),
                                                  )
                                                  : '-',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border.all(
                                            color: Color(0xFF6D5BFF),
                                            width: 1.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Bio',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              bio.isNotEmpty ? bio : '-',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Settings Section
                              Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Settings',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6D5BFF),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.edit,
                                          color: Color(0xFF6D5BFF),
                                        ),
                                        title: const Text('Edit Profile'),
                                        onTap: () {
                                          _showEditProfile(context, profile);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.lock,
                                          color: Color(0xFF6D5BFF),
                                        ),
                                        title: const Text('Change Password'),
                                        onTap: () {
                                          _showChangePassword(context);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Log Section
                              Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Log',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6D5BFF),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Example login report
                                      Row(
                                        children: const [
                                          Icon(
                                            Icons.login,
                                            color: Color(0xFF46C2CB),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Last login: 2024-05-01 14:23'),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed: () => _logout(context),
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            padding: EdgeInsets.zero,
                                            elevation: 4,
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.black26,
                                          ).copyWith(
                                            backgroundColor:
                                                MaterialStateProperty.resolveWith<
                                                  Color?
                                                >((states) => null),
                                          ),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFE53935),
                                                  Color(0xFFFF6F61),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Container(
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Logout',
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
                            ],
                          );
                        },
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

class EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onUpdated;
  const EditProfileDialog({
    required this.profile,
    required this.onUpdated,
    Key? key,
  }) : super(key: key);

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController usernameController;
  late TextEditingController nameController;
  late TextEditingController bioController;
  DateTime? birthday;
  String? avatarUrl;
  XFile? avatarFile;
  Uint8List? avatarBytes;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(
      text: widget.profile['username'] ?? '',
    );
    nameController = TextEditingController(text: widget.profile['name'] ?? '');
    bioController = TextEditingController(text: widget.profile['bio'] ?? '');
    avatarUrl = widget.profile['avatar_url'];
    birthday =
        widget.profile['birthday'] != null &&
                widget.profile['birthday'].toString().isNotEmpty
            ? DateTime.tryParse(widget.profile['birthday'])
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
      widget.onUpdated();
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6D5BFF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: isLoading ? null : _pickAvatar,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF46C2CB),
                  backgroundImage: avatarImage,
                  child: avatarChild,
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

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({Key? key}) : super(key: key);

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _changePassword() async {
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
    // final oldPassword = oldPasswordController.text;
    final newPassword = newPasswordController.text;
    try {
      // Re-authenticate (Supabase does not require old password for update)
      final res = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (res.user != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError('Failed to change password.');
      }
    } catch (e) {
      _showError('Failed to change password: $e');
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6D5BFF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _changePassword,
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
                                'Change Password',
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
