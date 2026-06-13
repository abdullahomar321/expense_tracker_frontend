import 'package:flutter/material.dart';


class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 50.0),
          child: Image.asset(
            'assets/images/trackit_logo_v4.png',
            width: 1000,
            height: 1000,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
