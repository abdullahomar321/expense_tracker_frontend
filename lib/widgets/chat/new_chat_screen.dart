import 'package:expense_tracker/api_calls/wallet_api.dart';
import 'package:expense_tracker/services/chat_service.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';
import 'package:expense_tracker/widgets/chat/chat_screen.dart';
import 'package:flutter/material.dart';

/// Screen for starting a new 1:1 chat.
/// Fetches users via WalletApi.fetchUsers() — the same /api/users endpoint
/// used in SendMoneyScreen and SplitBillHangoutScreen.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key, required this.currentUserId});

  final String currentUserId;

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final token = await SecureTokenStorage.getToken() ?? '';
    final result = await WalletApi.fetchUsers(token: token);

    if (!mounted) return;

    if (result['success'] == true) {
      final rawList = result['users'] as List<dynamic>? ?? [];
      final users = rawList
          .map((u) => Map<String, dynamic>.from(u as Map))
          // Exclude the current user from the list
          .where((u) => u['id']?.toString() != widget.currentUserId)
          .toList();

      setState(() {
        _allUsers = users;
        _filtered = users;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load users';
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allUsers
          : _allUsers.where((u) {
              final name = (u['name'] ?? '').toString().toLowerCase();
              final email = (u['email'] ?? '').toString().toLowerCase();
              return name.contains(query) || email.contains(query);
            }).toList();
    });
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    final otherId = user['id']?.toString() ?? '';
    if (otherId.isEmpty) return;

    // Create or fetch the chat document
    await ChatService.getOrCreateChat(widget.currentUserId, otherId);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.currentUserId,
          otherUserId: otherId,
          otherUserName: user['name']?.toString() ?? 'User',
          otherUserPhotoUrl:
              user['photo_url']?.toString() ?? user['avatar']?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF10B981), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Chat',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF10B981), size: 22),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFF10B981), width: 1.5),
                ),
              ),
            ),
          ),
          // User list
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadUsers();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final user = _filtered[index];
        final name = user['name']?.toString() ?? 'User';
        final email = user['email']?.toString() ?? '';
        final photoUrl = user['photo_url']?.toString() ??
            user['avatar']?.toString() ??
            '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: _buildAvatar(name, photoUrl),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              email,
              style:
                  const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFCF6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Chat',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            onTap: () => _startChat(user),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, String photoUrl) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.5, 0.45).toColor();
    return CircleAvatar(
      backgroundColor: color,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
