import 'package:expense_tracker/services/pin_service.dart';
import 'package:flutter/material.dart';

enum PinAuthMode { setup, verify }

class PinAuthScreen extends StatefulWidget {
  const PinAuthScreen({
    super.key,
    required this.mode,
    this.onSuccess,
  });

  final PinAuthMode mode;
  final VoidCallback? onSuccess;

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorText = '';

  void _onKeyPressed(String value) {
    setState(() {
      _errorText = '';
      if (_pin.length < 4) {
        _pin += value;
        if (_pin.length == 4) {
          _handlePinComplete();
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _errorText = '';
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _handlePinComplete() async {
    if (widget.mode == PinAuthMode.setup) {
      if (!_isConfirming) {
        // Switch to confirming state after a short delay for UX
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _confirmPin = _pin;
              _pin = '';
              _isConfirming = true;
            });
          }
        });
      } else {
        if (_pin == _confirmPin) {
          await PinService.savePin(_pin);
          if (mounted) {
            if (widget.onSuccess != null) {
              widget.onSuccess!();
            } else {
              Navigator.pop(context, true);
            }
          }
        } else {
          setState(() {
            _errorText = 'PINs do not match. Try again.';
            _pin = '';
            _confirmPin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Verify mode
      if (PinService.verifyPin(_pin)) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorText = 'Incorrect PIN';
          _pin = '';
        });
      }
    }
  }

  Widget _buildNumpadButton(String number) {
    return InkWell(
      onTap: () => _onKeyPressed(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: const Icon(
          Icons.backspace_outlined,
          color: Color(0xFF1F2937),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
            border: Border.all(
              color: isFilled ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
              width: 1,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title;
    if (widget.mode == PinAuthMode.setup) {
      title = _isConfirming ? 'Confirm PIN' : 'Create PIN';
    } else {
      title = 'Enter PIN';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.mode == PinAuthMode.setup
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context, false),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(
              Icons.lock_outline,
              size: 48,
              color: Color(0xFF10B981),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.mode == PinAuthMode.setup
                  ? 'Keep your account secure'
                  : 'Welcome back',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 48),
            _buildPinDots(),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                _errorText,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const Spacer(),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('1'),
                    _buildNumpadButton('2'),
                    _buildNumpadButton('3'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('4'),
                    _buildNumpadButton('5'),
                    _buildNumpadButton('6'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('7'),
                    _buildNumpadButton('8'),
                    _buildNumpadButton('9'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 80),
                    _buildNumpadButton('0'),
                    _buildBackspaceButton(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
