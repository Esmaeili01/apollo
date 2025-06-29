import 'package:flutter/material.dart';

class GroupProfilePage extends StatelessWidget {
  final Map<String, dynamic> group;
  const GroupProfilePage({required this.group, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarUrl = group['avatar_url'] as String?;
    final name = group['name'] as String? ?? 'Group';
    final description = group['description'] as String? ?? '';
    final members = group['members'] as List? ?? [];
    final isAdmin = group['is_admin'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: const Color(0xFF46C2CB),
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                child:
                                    (avatarUrl == null || avatarUrl.isEmpty)
                                        ? Text(
                                          name.isNotEmpty
                                              ? name
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 32,
                                          ),
                                        )
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${members.length} members',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (description.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Members',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...members.map(
                                (m) => Text(
                                  m['name'] ?? '-',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.black54),
                        onPressed: () {
                          // TODO: Implement group settings
                        },
                        tooltip: 'Group Settings',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
