import 'package:flutter/material.dart';
import 'settings.dart';
import 'search_page.dart';
import 'contacts_page.dart';
import 'private_chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isDialOpen = false;
  bool _isMenuOpen = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _chatOffset;
  late Animation<Offset> _groupOffset;
  late AnimationController _menuController;

  // Add state for selected chat type
  int _selectedChatTab = 0; // 0: PV, 1: Group

  List<Map<String, dynamic>> _privateChats = [];
  bool _loadingChats = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _chatOffset = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: const Offset(0, 0),
    ).animate(_controller);
    _groupOffset = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: const Offset(0, 0),
    ).animate(_controller);

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fetchPrivateChats();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    _menuController.dispose();
    super.dispose();
  }

  void _toggleDial() {
    setState(() {
      _isDialOpen = !_isDialOpen;
      if (_isDialOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _closeDial() {
    setState(() {
      _isDialOpen = false;
      _controller.reverse();
    });
  }

  Future<void> _fetchPrivateChats() async {
    setState(() => _loadingChats = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // Get all private chats (messages where sender or receiver is current user, group_id is null)
    final res = await Supabase.instance.client
        .from('messages')
        .select(
          'id, sender_id, receiver_id, content, created_at, is_read, sender:sender_id (id, name, avatar_url), receiver:receiver_id (id, name, avatar_url)',
        )
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .is_('group_id', null)
        .order('created_at', ascending: false);
    // Group by contact (other user)
    final Map<String, Map<String, dynamic>> chatMap = {};
    for (final msg in res) {
      final isSender = msg['sender_id'] == user.id;
      final contact = isSender ? msg['receiver'] : msg['sender'];
      if (contact == null || contact['id'] == null) continue;
      final contactId = contact['id'];
      if (!chatMap.containsKey(contactId)) {
        chatMap[contactId] = {
          'contact': contact,
          'lastMessage': msg['content'],
          'lastMessageTime': msg['created_at'],
          'isRead': msg['is_read'],
        };
      }
    }
    setState(() {
      _privateChats = chatMap.values.toList();
      _loadingChats = false;
    });
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('id, name, avatar_url')
            .eq('id', user.id)
            .single();
    setState(() {
      _userProfile = res;
    });
  }

  void _onNewChat() {
    _closeDial();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactsPage()),
    );
  }

  void _onNewGroup() {
    _closeDial();
    // TODO: Implement new group
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _menuController.forward();
      } else {
        _menuController.reverse();
      }
    });
  }

  void _closeMenu() {
    setState(() {
      _isMenuOpen = false;
      _menuController.reverse();
    });
  }

  void _onMenuOption(String value) {
    _closeMenu();
    if (value == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );
    }
    if (value == 'contacts') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ContactsPage()),
      );
    }
    if (value == 'blocks') {
      // TODO: Navigate to blocks page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apollo', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
          ],
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
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: _toggleMenu,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFFF5F6FA),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: _ChatTabs(
                    selected: _selectedChatTab,
                    onSelect: (i) => setState(() => _selectedChatTab = i),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! < -200 &&
                            _selectedChatTab == 0) {
                          setState(
                            () => _selectedChatTab = 1,
                          ); // Swipe left: PV -> Groups
                        } else if (details.primaryVelocity! > 200 &&
                            _selectedChatTab == 1) {
                          setState(
                            () => _selectedChatTab = 0,
                          ); // Swipe right: Groups -> PV
                        }
                      }
                    },
                    child:
                        _selectedChatTab == 0
                            ? _loadingChats
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : _privateChats.isEmpty
                                ? const Center(
                                  child: Text('No private chats yet.'),
                                )
                                : ListView.separated(
                                  itemCount: _privateChats.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, i) {
                                    final chat = _privateChats[i];
                                    final contact =
                                        chat['contact'] as Map<String, dynamic>;
                                    final avatarUrl =
                                        contact['avatar_url'] as String?;
                                    final name =
                                        contact['name'] as String? ?? '';
                                    final lastMessage =
                                        chat['lastMessage'] as String? ?? '';
                                    final lastMessageTime =
                                        chat['lastMessageTime'] as String?;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(
                                          0xFF46C2CB,
                                        ),
                                        backgroundImage:
                                            avatarUrl != null &&
                                                    avatarUrl.isNotEmpty
                                                ? NetworkImage(avatarUrl)
                                                : null,
                                        child:
                                            avatarUrl == null ||
                                                    avatarUrl.isEmpty
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
                                      title: Text(name),
                                      subtitle: Text(
                                        lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing:
                                          lastMessageTime != null
                                              ? Text(
                                                lastMessageTime
                                                    .substring(0, 16)
                                                    .replaceAll('T', ' '),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              )
                                              : null,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => PrivateChatPage(
                                                  contact: contact,
                                                ),
                                          ),
                                        ).then((_) => _fetchPrivateChats());
                                      },
                                    );
                                  },
                                )
                            : const Center(
                              child: Text(
                                'Group Chats List',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
          if (_isDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDial,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withAlpha((0.15 * 255).toInt()),
                ),
              ),
            ),
          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          if (_isMenuOpen)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 160,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _menuController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: _AnimatedMenu(
                      controller: _menuController,
                      onMenuOption: _onMenuOption,
                      isDrawer: true,
                      userProfile: _userProfile,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isDialOpen) ...[
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _groupOffset,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: FloatingActionButton(
                          heroTag: 'group',
                          mini: true,
                          onPressed: () {
                            _closeDial();
                            // TODO: Implement new group
                          },
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: const Icon(
                            Icons.group_add,
                            color: Colors.white,
                          ),
                          tooltip: 'New Group',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _chatOffset,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: FloatingActionButton(
                          heroTag: 'chat',
                          mini: true,
                          onPressed: _onNewChat,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: const Icon(Icons.chat, color: Colors.white),
                          tooltip: 'New Chat',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ],
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: FloatingActionButton(
                onPressed: _isDialOpen ? _closeDial : _toggleDial,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: AnimatedRotation(
                  turns: _isDialOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isDialOpen ? Icons.close : Icons.add,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMenu extends StatelessWidget {
  final AnimationController controller;
  final void Function(String value) onMenuOption;
  final bool isDrawer;
  final Map<String, dynamic>? userProfile;
  const _AnimatedMenu({
    required this.controller,
    required this.onMenuOption,
    this.isDrawer = false,
    this.userProfile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<_MenuOptionData> options = [
      _MenuOptionData('settings', Icons.settings, 'Settings'),
      _MenuOptionData('contacts', Icons.contacts, 'Contacts'),
      _MenuOptionData('blocks', Icons.block, 'Blocks'),
    ];
    return Container(
      width: isDrawer ? 160 : 200,
      height: isDrawer ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isDrawer ? 0 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.15 * 255).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: isDrawer ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userProfile != null) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF46C2CB),
                      backgroundImage:
                          (userProfile!['avatar_url'] != null &&
                                  userProfile!['avatar_url'].isNotEmpty)
                              ? NetworkImage(userProfile!['avatar_url'])
                              : null,
                      child:
                          (userProfile!['avatar_url'] == null ||
                                  userProfile!['avatar_url'].isEmpty)
                              ? Text(
                                userProfile!['name'] != null &&
                                        userProfile!['name'].isNotEmpty
                                    ? userProfile!['name'][0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              )
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userProfile!['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white70, thickness: 1, height: 1),
            ],
            ...List.generate(options.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                  top: i == 0 ? 32 : 0,
                  left: 8,
                  right: 8,
                  bottom: 8,
                ),
                child: _MenuOption(
                  icon: options[i].icon,
                  label: options[i].label,
                  onTap: () => onMenuOption(options[i].value),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MenuOptionData {
  final String value;
  final IconData icon;
  final String label;
  const _MenuOptionData(this.value, this.icon, this.label);
}

// Chat tabs (centered, pill-shaped)
class _ChatTabs extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  const _ChatTabs({required this.selected, required this.onSelect, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatTab(
            label: 'PV',
            selected: selected == 0,
            onTap: () => onSelect(0),
          ),
          const SizedBox(width: 8),
          _ChatTab(
            label: 'Groups',
            selected: selected == 1,
            onTap: () => onSelect(1),
          ),
        ],
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChatTab({
    required this.label,
    required this.selected,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF6D5BFF) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
