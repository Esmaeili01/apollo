import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'private_chat.dart';

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _dialogError;
  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
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
        if (profileRes != null) {
          profileRes['nickname'] = contact['nickname'];
          contactsWithProfiles.add(profileRes);
        }
      }

      setState(() {
        _contacts = contactsWithProfiles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        _contacts = [];
        _error = 'Failed to load contacts';
        _isLoading = false;
      });
    }
  }


  Future<void> _removeContact(String contactId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    await Supabase.instance.client
        .from('contacts')
        .delete()
        .eq('user_id', user.id)
        .eq('contact_id', contactId);
    setState(() {
      _contacts.removeWhere((c) => c['id'] == contactId);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts', style: TextStyle(color: Colors.white)),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                  ? const Center(child: Text('No contacts yet.'))
                  : ListView.separated(
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = _contacts[i];
                        final avatarUrl = c['avatar_url'] as String?;
                        final name = c['name'] as String? ?? '';
                        final bio = c['bio'] as String? ?? '';
                        final lastSeen = c['last_seen'];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PrivateChat(contact: c),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF6D5BFF),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
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
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (c['is_online'] == true)
                                    Text(
                                      'online',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else if (lastSeen != null)
                                    Text(
                                      _getStatusText(lastSeen),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: null,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _showRemoveContactDialog(
                                  c['id'] as String,
                                  c['name'] as String? ?? '',
                                ),
                                tooltip: 'Remove',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddContactDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
          tooltip: 'Add Contact',
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final nicknameController = TextEditingController();
    _dialogError = null;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Add Contact'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _dialogError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0xFF6D5BFF),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0xFF46C2CB),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // TextField(
                    //   controller: nicknameController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Nickname',
                    //     border: OutlineInputBorder(
                    //       borderRadius: BorderRadius.all(Radius.circular(16)),
                    //     ),
                    //     enabledBorder: OutlineInputBorder(
                    //       borderRadius: BorderRadius.all(Radius.circular(16)),
                    //       borderSide: BorderSide(
                    //         color: Color(0xFF6D5BFF),
                    //         width: 1.5,
                    //       ),
                    //     ),
                    //     focusedBorder: OutlineInputBorder(
                    //       borderRadius: BorderRadius.all(Radius.circular(16)),
                    //       borderSide: BorderSide(
                    //         color: Color(0xFF46C2CB),
                    //         width: 2,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ).copyWith(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color?>(
                              (states) => null,
                            ),
                      ),
                  onPressed: () async {
                    final username = usernameController.text.trim();
                    // final nickname = nicknameController.text.trim();
                    if (username.isEmpty) {
                      setDialogState(() {
                        _dialogError = 'Please enter username.';
                      });
                      return;
                    }

                    // Check if user is logged in
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user == null) {
                      setDialogState(() {
                        _dialogError = 'Not logged in.';
                      });
                      return;
                    }

                    // Find the user by username
                    final res = await Supabase.instance.client
                        .from('profiles')
                        .select('id, name, bio, avatar_url')
                        .eq('username', username)
                        .maybeSingle();

                    if (res == null) {
                      setDialogState(() {
                        _dialogError = 'No user found with this username.';
                      });
                      return;
                    }

                    if (res['id'] == user.id) {
                      setDialogState(() {
                        _dialogError = 'You cannot add yourself.';
                      });
                      return;
                    }

                    // Prevent duplicates
                    if (_contacts.any((c) => c['id'] == res['id'])) {
                      setDialogState(() {
                        _dialogError = 'This user is already in your contacts.';
                      });
                      return;
                    }
                  
                    final insertRes =
                        await Supabase.instance.client.from('contacts').insert({
                          'user_id': user.id,
                          'contact_id': res['id'],
                          'nickname': res['name'],
                        }).select();

                    if (insertRes == null || insertRes.isEmpty) {
                      setDialogState(() {
                        _dialogError =
                            'Failed to add contact. Please try again.';
                      });
                      return;
                    }

                    // Success - close dialog and update contacts
                    Navigator.of(context).pop();
                    setState(() {
                      _contacts.add(res);
                      _isLoading = false;
                      _error = null;
                    });
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getStatusText(dynamic lastSeen) {
    if (lastSeen == null) return 'last seen recently';
    final dt = DateTime.tryParse(lastSeen.toString())?.toLocal();
    if (dt == null) return 'last seen recently';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24 && now.day == dt.day) {
      return 'last seen ${diff.inHours} hr ago';
    }
    if (diff.inHours < 48 && now.day - dt.day == 1) {
      return 'last seen yesterday at ${_formatTime(dt)}';
    }
    return 'last seen on ${_formatDate(dt)} at ${_formatTime(dt)}';
  }

  String _formatTime(DateTime dt) {
    return dt.hour.toString().padLeft(2, '0') +
        ':' +
        dt.minute.toString().padLeft(2, '0');
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  }

  void _showRemoveContactDialog(String contactId, String contactName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Remove Contact'),
          content: Text(
            'Are you sure you want to remove $contactName from your contacts?',
          ),
          actions: [
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ).copyWith(
                    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                      (states) => null,
                    ),
                  ),
              onPressed: () {
                Navigator.of(context).pop();
                _removeContact(contactId);
              },
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ).copyWith(
                    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                      (states) => null,
                    ),
                  ),
              onPressed: () => Navigator.of(context).pop(),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
