import 'package:flutter/material.dart';
import 'package:expense_tracker/widgets/ai_chatbot_screen.dart';
import 'package:expense_tracker/widgets/dashboard_bottom_nav.dart';
import 'package:expense_tracker/widgets/home_screen.dart';
import 'package:expense_tracker/widgets/settings_screen.dart';
import 'package:expense_tracker/widgets/send_money_screen.dart';
import 'package:expense_tracker/widgets/transaction_history_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late int _selectedIndex;

  static const _titles = [
    'AI ChatBot',
    'Settings',
    'Transactions',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: isHome
            ? null
            : Text(
                _titles[_selectedIndex - 1],
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            onSendMoney: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SendMoneyScreen(),
              ),
            ),
          ),
          const AiChatbotScreen(),
          const SettingsScreen(),
          const TransactionHistoryScreen(),
        ],
      ),
      bottomNavigationBar: DashboardBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
