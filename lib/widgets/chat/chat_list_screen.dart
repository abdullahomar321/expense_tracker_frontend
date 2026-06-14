import 'package:expense_tracker/api_calls/wallet_api.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';
import 'package:expense_tracker/models/chat_room.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/chat_service.dart';
import 'package:expense_tracker/widgets/chat/chat_screen.dart';
import 'package:expense_tracker/widgets/chat/new_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Map<String, dynamic> _fallbackUsers = {};

  @override
  void initState() {
    super.initState();
    _loadFallbackUsers();
  }

  Future<void> _loadFallbackUsers() async {
    final token = await SecureTokenStorage.getToken() ?? '';
    if (token.isEmpty) return;
    
    final result = await WalletApi.fetchUsers(token: token);
    if (mounted && result['success'] == true) {
      final list = result['users'] as List<dynamic>? ?? [];
      final map = <String, dynamic>{};
      for (final u in list) {
        map[u['id'].toString()] = u;
      }
      setState(() {
        _fallbackUsers = map;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.watch<UserProvider>().userId;

    if (currentUserId.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context, currentUserId),
        body: const Center(
          child: Text(
            'Please log in to use chat.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context, currentUserId),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        tooltip: 'New Chat',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewChatScreen(currentUserId: currentUserId),
          ),
        ),
        child: const Icon(Icons.edit_outlined),
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: ChatService.getChatListStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading chats:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
            );
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined,
                      size: 72, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 20),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the ✏ button to start chatting\nwith someone on the platform.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('New Chat',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            NewChatScreen(currentUserId: currentUserId),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return _ChatTile(
                room: room,
                currentUserId: currentUserId,
                fallbackUsers: _fallbackUsers,
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, String currentUserId) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Color(0xFF10B981), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Messages',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual chat tile — fetches the other user's profile from Firestore
// ---------------------------------------------------------------------------

class _ChatTile extends StatefulWidget {
  const _ChatTile({
    required this.room,
    required this.currentUserId,
    required this.fallbackUsers,
  });

  final ChatRoom room;
  final String currentUserId;
  final Map<String, dynamic> fallbackUsers;

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  Map<String, dynamic>? _otherProfile;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final otherId = widget.room.otherUserId(widget.currentUserId);
    if (otherId.isEmpty) {
      setState(() => _profileLoaded = true);
      return;
    }
    final profile = await ChatService.getUserProfile(otherId);
    if (mounted) {
      setState(() {
        _otherProfile = profile;
        _profileLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final otherId = room.otherUserId(widget.currentUserId);
    final fallbackUser = widget.fallbackUsers[otherId];

    final otherName = _otherProfile?['displayName']?.toString() ??
        fallbackUser?['name']?.toString() ??
        'User';
    final otherPhotoUrl = _otherProfile?['photoUrl']?.toString() ??
        fallbackUser?['photo_url']?.toString() ??
        fallbackUser?['avatar']?.toString() ??
        '';
    final lastMsg = room.lastMessage;
    final lastText = lastMsg?['text']?.toString() ?? '';
    final unread = room.unreadFor(widget.currentUserId);

    // Timestamp display
    String timeStr = '';
    if (lastMsg != null && lastMsg['timestamp'] != null) {
      try {
        final ts = lastMsg['timestamp'];
        DateTime dt;
        if (ts is DateTime) {
          dt = ts;
        } else {
          // Firestore Timestamp in lastMessage map — try casting
          dt = (ts as dynamic).toDate() as DateTime;
        }
        final now = DateTime.now();
        if (dt.day == now.day &&
            dt.month == now.month &&
            dt.year == now.year) {
          timeStr = DateFormat('h:mm a').format(dt);
        } else {
          timeStr = DateFormat('MMM d').format(dt);
        }
      } catch (_) {}
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUserId: widget.currentUserId,
            otherUserId: otherId,
            otherUserName: otherName,
            otherUserPhotoUrl: otherPhotoUrl,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(otherName, otherPhotoUrl, loaded: _profileLoaded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 15,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: unread > 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                          fontWeight: unread > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastText.isEmpty ? 'No messages yet' : lastText,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? const Color(0xFF334155)
                                : const Color(0xFF94A3B8),
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String photoUrl,
      {required bool loaded}) {
    if (!loaded) {
      return const CircleAvatar(
        radius: 26,
        backgroundColor: Color(0xFFE2E8F0),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF10B981)),
        ),
      );
    }

    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hue =
        (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.5, 0.45).toColor();

    return CircleAvatar(
      radius: 26,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
