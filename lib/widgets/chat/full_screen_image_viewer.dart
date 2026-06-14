import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Full-screen zoomable image viewer for base64-encoded chat images.
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({super.key, required this.imageBase64});

  final String imageBase64;

  @override
  Widget build(BuildContext context) {
    late final Uint8List bytes;
    bool decodeError = false;

    try {
      bytes = base64Decode(imageBase64);
    } catch (_) {
      decodeError = true;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Screenshot',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: decodeError
          ? const Center(
              child: Text(
                'Could not display image.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
    );
  }
}
