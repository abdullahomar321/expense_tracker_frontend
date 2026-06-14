import 'package:flutter/material.dart';
import 'package:expense_tracker/widgets/split_bill_receipt_screen.dart';
import 'package:expense_tracker/api_calls/wallet_api.dart';
import 'package:expense_tracker/api_calls/hangout_api.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';
import 'package:expense_tracker/widgets/chat/chat_list_screen.dart';

class SplitBillHangoutScreen extends StatefulWidget {
  const SplitBillHangoutScreen({super.key});

  @override
  State<SplitBillHangoutScreen> createState() => _SplitBillHangoutScreenState();
}

class _SplitBillHangoutScreenState extends State<SplitBillHangoutScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final List<String> _members = []; // emails of selected members
  List<dynamic> _allUsers = []; // full user objects {id, name, email} from DB
  List<Map<String, dynamic>> _suggestedUsers = []; // filtered users for dropdown
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadAllUsers(); // Fetch users once on screen load
  }

  // --- API CALL: Fetch Users from WalletApi ---
  Future<void> _loadAllUsers() async {
    final token = await SecureTokenStorage.getToken() ?? '';

    final result = await WalletApi.fetchUsers(token: token);
    if (result['success']) {
      setState(() {
        _allUsers = result['users'];
      });
    } else {
      _showSnackBar(result['message'] ?? 'Failed to load users');
    }
  }

  // --- Search Logic (Searchable Dropdown) ---
  void _searchUsers(String query) {
    if (query.isEmpty) {
      setState(() => _suggestedUsers = []);
      return;
    }

    setState(() {
      _suggestedUsers = _allUsers
          .map((user) => {
        "id": user['id'],
        "name": user['name'].toString(),
        "email": user['email'].toString(),
      })
          .where((user) =>
      (user['name'] as String).toLowerCase().contains(query.toLowerCase()) &&
          !_members.contains(user['email']))
          .toList();
    });
  }

  // --- API CALL: Create Hangout ---
  Future<void> _handleGenerateReceipt() async {
    if (_nameController.text.isEmpty) {
      _showSnackBar('Please enter a hangout name');
      return;
    }
    if (_members.isEmpty) {
      _showSnackBar('Please add at least one member');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final token = await SecureTokenStorage.getToken() ?? '';

      final result = await HangoutApi.createHangout(
        token: token,
        name: _nameController.text.trim(),
        emails: _members,
      );

      if (result['success']) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SplitBillReceiptScreen(
              hangoutName: _nameController.text,
              members: _members,
            ),
          ),
        );
      } else {
        _showSnackBar(result['message'] ?? 'Failed to create hangout.');
      }
    } catch (e) {
      _showSnackBar('An error occurred while connecting to server.');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _addMember(String email) {
    if (email.isNotEmpty && !_members.contains(email)) {
      setState(() {
        _members.add(email);
        _suggestedUsers = [];
      });
      _emailController.clear();
    }
  }

  void _removeMember(String email) {
    setState(() => _members.remove(email));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI REMAINS EXACTLY THE SAME AS REQUESTED
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF10B981)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChatListScreen(),
              ),
            ),
            icon: const Icon(Icons.wechat_outlined,color: Colors.green,),
          )
        ],
        title: const Text(
          'Split a Bill',
          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('Hangout Name'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              hint: 'e.g. Weekend Trip',
              icon: Icons.local_dining,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Add Members'),
            const SizedBox(height: 12),
            Stack(
              clipBehavior: Clip.none, // Ensures dropdown doesn't get cut off
              children: [
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            decoration: _inputDecoration('Search by name', Icons.person_add),
                            onChanged: _searchUsers,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildAddButton(() {
                          final query = _emailController.text.trim().toLowerCase();
                          if (query.isEmpty) return;

                          // Try to find an exact name or email match among all users
                          final match = _allUsers.firstWhere(
                                (user) =>
                            user['name'].toString().toLowerCase() == query ||
                                user['email'].toString().toLowerCase() == query,
                            orElse: () => null,
                          );

                          if (match != null) {
                            _addMember(match['email'].toString());
                          } else {
                            _showSnackBar('No matching user found');
                          }
                        }),
                      ],
                    ),
                    if (_suggestedUsers.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestedUsers.length,
                          itemBuilder: (context, index) {
                            final user = _suggestedUsers[index];
                            return ListTile(
                              title: Text(user['name'] as String),
                              subtitle: Text(user['email'] as String),
                              onTap: () => _addMember(user['email'] as String),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_members.isNotEmpty) _buildMembersList(),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isCreating ? null : _handleGenerateReceipt,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isCreating
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Generate Receipt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Methods (Unchanged) ---
  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)));
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon}) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(hint, icon),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  Widget _buildAddButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMembersList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _members.map((email) {
          // Display name if we have it, fall back to email
          final user = _allUsers.firstWhere(
                (u) => u['email'] == email,
            orElse: () => null,
          );
          final label = user != null ? user['name'].toString() : email;

          return Chip(
            backgroundColor: const Color(0xFFEFFCF6),
            label: Text(label, style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600)),
            onDeleted: () => _removeMember(email),
            deleteIcon: const Icon(Icons.close, size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        }).toList(),
      ),
    );
  }
}