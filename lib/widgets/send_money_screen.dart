import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/secure_token_storage.dart';
import '../api_calls/wallet_api.dart';
import 'transaction_success_screen.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  bool _isLoadingUsers = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoadingUsers = false; });
      return;
    }

    final response = await WalletApi.fetchUsers(token: token);
    if (mounted) {
      if (response['success']) {
        final usersList = response['users'] as List<dynamic>;
        setState(() {
          _users = usersList.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoadingUsers = false;
        });
      } else {
        setState(() { _isLoadingUsers = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to load users')),
        );
      }
    }
  }

  Future<void> _sendMoney() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient from the list')),
      );
      return;
    }

    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() { _isSending = true; });

    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      setState(() { _isSending = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unauthenticated. Please log in again.')),
        );
      }
      return;
    }

    final email = _selectedUser!['email'];
    final note = _noteController.text;

    final response = await WalletApi.sendMoney(
      token: token,
      email: email,
      amount: amount,
      note: note,
    );

    if (mounted) {
      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Money sent successfully!')),
        );
        
        // Fetch updated balance
        final balanceResp = await WalletApi.fetchBalance(token: token);
        if (mounted && balanceResp['success']) {
           final newBalance = balanceResp['balance'];
           double parsedBalance = 0;
           if (newBalance is num) {
             parsedBalance = newBalance.toDouble();
           } else if (newBalance is String) {
             parsedBalance = double.tryParse(newBalance) ?? 0;
           }
           context.read<UserProvider>().updateBalance(parsedBalance);
        }
        
        if (mounted) {
          final recipientName = _selectedUser!['name'] ?? 'Unknown User';
          final recipientEmail = _selectedUser!['email'] ?? '';
          
          // Clear inputs for the next potential transaction
          _amountController.clear();
          _noteController.clear();
          setState(() {
            _selectedUser = null;
            _isSending = false;
          });

          // Navigate to success screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionSuccessScreen(
                amount: amount,
                recipientName: recipientName,
                recipientEmail: recipientEmail,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to send money')),
        );
        setState(() { _isSending = false; });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final balance = user.balance;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF10B981)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Send Money',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Available Balance Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Recipient Details
              const Text(
                'Recipient',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  return _users.where((user) {
                    final name = user['name']?.toString().toLowerCase() ?? '';
                    final email = user['email']?.toString().toLowerCase() ?? '';
                    final query = textEditingValue.text.toLowerCase();
                    return name.contains(query) || email.contains(query);
                  });
                },
                displayStringForOption: (Map<String, dynamic> option) => option['email'] ?? '',
                onSelected: (Map<String, dynamic> selection) {
                  setState(() {
                    _selectedUser = selection;
                  });
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: _isLoadingUsers ? 'Loading recipients...' : 'Search by name or email',
                      prefixIcon: _isLoadingUsers 
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))
                              ),
                            )
                          : const Icon(Icons.alternate_email, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (val) {
                      if (_selectedUser != null && _selectedUser!['email'] != val) {
                        setState(() {
                          _selectedUser = null;
                        });
                      }
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 48,
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                                child: const Icon(Icons.person, color: Color(0xFF10B981)),
                              ),
                              title: Text(option['name'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(option['email'] ?? ''),
                              onTap: () {
                                onSelected(option);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Amount
              const Text(
                'Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 32,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                ),
              ),
              const SizedBox(height: 24),
              
              // Note
              const Text(
                'Note (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'What is this for?',
                  prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 40),
              
              // Send Button
              ElevatedButton(
                onPressed: _isSending ? null : _sendMoney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                ),
                child: _isSending 
                  ? const SizedBox(
                      height: 24, 
                      width: 24, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Text(
                      'Send Money',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
