import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GroupCreate extends StatefulWidget {
  const GroupCreate({super.key});

  @override
  State<GroupCreate> createState() => _GroupCreateState();
}

class _GroupCreateState extends State<GroupCreate> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isPublic = true;
  File? _avatarFile;
  bool _picking = false;

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

  @override
  Widget build(BuildContext context) {
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFF46C2CB),
                      backgroundImage:
                          _avatarFile != null ? FileImage(_avatarFile!) : null,
                      child:
                          _avatarFile == null
                              ? const Icon(
                                Icons.group,
                                color: Colors.white,
                                size: 48,
                              )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Row(
                        children: [
                          if (_avatarFile != null)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 22,
                              ),
                              onPressed: _removeAvatar,
                              tooltip: 'Remove avatar',
                            ),
                          IconButton(
                            icon: Icon(
                              _picking ? Icons.hourglass_top : Icons.camera_alt,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: _picking ? null : _pickAvatar,
                            tooltip: 'Pick avatar',
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      label: const Text('Public'),
                      selected: _isPublic,
                      onSelected: (v) => setState(() => _isPublic = true),
                      selectedColor: const Color(0xFF46C2CB),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Private'),
                      selected: !_isPublic,
                      onSelected: (v) => setState(() => _isPublic = false),
                      selectedColor: const Color(0xFF6D5BFF),
                    ),
                  ],
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
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // TODO: Implement group creation logic
                      }
                    },
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
