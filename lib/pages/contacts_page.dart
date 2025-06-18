import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'private_chat_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
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
        final profileRes =
            await Supabase.instance.client
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

  Future<void> _addContact() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please enter a username.';
      });
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Not logged in.';
      });
      return;
    }
    // Find the user by username
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('id, name, bio, avatar_url')
            .eq('username', username)
            .maybeSingle();
    if (res == null) {
      setState(() {
        _isLoading = false;
        _error = 'No user found';
      });
      return;
    }
    if (res['id'] == user.id) {
      setState(() {
        _isLoading = false;
        _error = 'You cannot add yourself.';
      });
      return;
    }
    // Prevent duplicates
    if (_contacts.any((c) => c['id'] == res['id'])) {
      setState(() {
        _isLoading = false;
        _error = 'Already in contacts.';
      });
      return;
    }
    // Insert into contacts table
    final insertRes =
        await Supabase.instance.client.from('contacts').insert({
          'user_id': user.id,
          'contact_id': res['id'],
        }).select();
    if (insertRes == null || insertRes.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to add contact.';
      });
      return;
    }
    setState(() {
      _contacts.add(res);
      _isLoading = false;
      _error = null;
      _usernameController.clear();
    });
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
              child:
                  _isLoading
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
                                  builder:
                                      (context) => PrivateChatPage(contact: c),
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
                                  child:
                                      avatarUrl == null || avatarUrl.isEmpty
                                          ? Text(
                                            name.isNotEmpty
                                                ? name
                                                    .substring(0, 1)
                                                    .toUpperCase()
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
                                    if (c['is_online'] == true ||
                                        _isRecentlyOnline(lastSeen))
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
                                        'Last seen: ${_formatLastSeen(lastSeen)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: bio.isNotEmpty ? Text(bio) : null,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => _removeContact(c['id'] as String),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
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
              onPressed: () async {
                final username = usernameController.text.trim();
                final nickname = nicknameController.text.trim();
                if (username.isEmpty || nickname.isEmpty) {
                  setState(() {
                    _error = 'Please enter both username and nickname.';
                  });
                  return;
                }
                Navigator.of(context).pop();
                await _addContactWithNickname(username, nickname);
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
  }

  Future<void> _addContactWithNickname(String username, String nickname) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Not logged in.';
      });
      return;
    }
    // Find the user by username
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('id, name, bio, avatar_url')
            .eq('username', username)
            .maybeSingle();
    if (res == null) {
      setState(() {
        _isLoading = false;
        _error = 'No user found';
      });
      return;
    }
    if (res['id'] == user.id) {
      setState(() {
        _isLoading = false;
        _error = 'You cannot add yourself.';
      });
      return;
    }
    // Prevent duplicates
    if (_contacts.any((c) => c['id'] == res['id'])) {
      setState(() {
        _isLoading = false;
        _error = 'Already in contacts.';
      });
      return;
    }
    // Insert into contacts table with nickname
    final insertRes =
        await Supabase.instance.client.from('contacts').insert({
          'user_id': user.id,
          'contact_id': res['id'],
          'nickname': nickname,
        }).select();
    if (insertRes == null || insertRes.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to add contact.';
      });
      return;
    }
    setState(() {
      _contacts.add(res);
      _isLoading = false;
      _error = null;
    });
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
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  bool _isRecentlyOnline(dynamic lastSeen) {
    if (lastSeen == null) return false;
    final dt = DateTime.tryParse(lastSeen.toString());
    if (dt == null) return false;
    return DateTime.now().difference(dt).inMinutes < 2;
  }
}
