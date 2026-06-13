import 'package:expense_tracker/api_calls/gemini_api.dart';
import 'package:expense_tracker/api_calls/premium_api.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/expense_context_service.dart';
import 'package:expense_tracker/widgets/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  State<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _isSending = false;
  bool _isRefreshingStatus = false;

  static const _accent = Color(0xFF10B981);
  static const _dark = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        text: 'Hi! I am your expense assistant. Ask me about saving money, reducing expenses, or improving your budget.',
        isUser: false,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPremiumStatus();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPremiumStatus() async {
    if (_isRefreshingStatus) return;
    setState(() => _isRefreshingStatus = true);

    final result = await PremiumApi.getPremiumStatus();
    if (!mounted) return;

    if (result.success) {
      context.read<UserProvider>().setPremium(result.isPremium);
    }

    setState(() => _isRefreshingStatus = false);
  }

  Future<void> _openSubscription() async {
    final upgraded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );

    if (!mounted) return;

    if (upgraded == true) {
      await _refreshPremiumStatus();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final userProvider = context.read<UserProvider>();
    if (!userProvider.isPremium) {
      setState(() {
        _messages.add(_ChatMessage(text: text, isUser: true));
        _messages.add(
          const _ChatMessage(
            text: 'This feature requires a premium subscription.',
            isUser: false,
            isError: true,
          ),
        );
        _messageController.clear();
      });
      _scrollToBottom();
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    final expenseContext = await ExpenseContextService.loadContext(
      currentIncome: userProvider.totalIncome,
      currentBalance: userProvider.balance,
    );

    final result = await GeminiApi.sendMessage(
      message: text,
      expenses: expenseContext.expenses,
      financialContext: ExpenseContextService.buildFinancialSnapshot(expenseContext),
    );

    if (!mounted) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: result.success
              ? (result.reply?.isNotEmpty == true ? result.reply! : result.message)
              : result.message,
          isUser: false,
          isError: !result.success,
        ),
      );
      _isSending = false;
    });
    _scrollToBottom();

    if (!result.success && result.statusCode == 403) {
      context.read<UserProvider>().setPremium(false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildLockedView(UserProvider user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFCF6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.lock_open_rounded, color: _accent, size: 40),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Unlock your AI expense assistant',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _dark,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Premium gives ${user.name.isEmpty ? 'you' : user.name.split(' ').first} a finance-focused chatbot that helps with savings and budget planning.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                _buildInfoPill(Icons.workspace_premium, 'Premium required'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _openSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Upgrade with Stripe',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildFeatureCard(
            Icons.insights_outlined,
            'Budget analysis',
            'See how much you have spent and where your money is going.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            Icons.category_outlined,
            'Category coaching',
            'Ask which categories are highest and where you can cut back first.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            Icons.history_toggle_off,
            'Persistent access',
            'Once subscribed, access comes back after login because premium is checked from the server.',
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(UserProvider user) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFFCF6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.smart_toy_outlined, color: _accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense assistant for ${user.name.isEmpty ? 'you' : user.name.split(' ').first}',
                            style: const TextStyle(
                              color: _dark,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Premium access confirmed. Ask your assistant about savings, categories, or spending habits.',
                            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildInfoPill(Icons.workspace_premium, 'Premium active'),
                    const SizedBox(width: 8),
                    _buildInfoPill(Icons.account_balance_wallet_outlined, 'Budget \$${user.totalIncome.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: _messages.length + (_isSending ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isSending && index == _messages.length) {
                return const _TypingBubble();
              }
              final message = _messages[index];
              return _MessageBubble(message: message);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SuggestionChip(
                      label: 'How can I reduce my monthly expenses?',
                      onTap: () => _messageController.text = 'How can I reduce my monthly expenses?',
                    ),
                    _SuggestionChip(
                      label: 'Help me save more this month',
                      onTap: () => _messageController.text = 'Help me save more this month',
                    ),
                    _SuggestionChip(
                      label: 'Give me budgeting tips',
                      onTap: () => _messageController.text = 'Give me budgeting tips',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Ask about your expenses or savings...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: _surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _sendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFCF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _dark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFCF6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Container(
      color: const Color(0xFFFDFDFC),
      child: _isRefreshingStatus && !user.isPremium
          ? const Center(
              child: CircularProgressIndicator(color: _accent),
            )
          : user.isPremium
              ? _buildChatView(user)
              : _buildLockedView(user),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser
        ? const Color(0xFF10B981)
        : message.isError
            ? const Color(0xFFFEF2F2)
            : Colors.white;
    final textColor = message.isUser
        ? Colors.white
        : message.isError
            ? const Color(0xFFB91C1C)
            : const Color(0xFF0F172A);
    final border = message.isUser
        ? null
        : Border.all(color: message.isError ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0));

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
            border: border,
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF10B981),
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
