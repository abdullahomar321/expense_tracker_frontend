import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:expense_tracker/services/pin_service.dart';

/// Handles image picking, compression, and base64 encoding for chat.
class ImageCompressService {
  static const int _maxBase64Bytes = 700 * 1024; // 700 KB limit
  static const int _maxWidthPx = 1024;
  static const int _qualityPercent = 65;

  /// Picks an image from [source] (gallery or camera), compresses it,
  /// encodes to base64, and returns the string.
  ///
  /// Returns `null` if the user cancelled, or if the compressed image is
  /// still too large (in which case [onError] is called with a message).
  static Future<String?> pickAndEncode({
    required ImageSource source,
    required void Function(String message) onError,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source);
      if (picked == null) return null; // User cancelled

      final originalBytes = await picked.readAsBytes();

      // Compress: resize to max 1024px width, quality 65
      final compressedBytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: _maxWidthPx,
        minHeight: _maxWidthPx,
        quality: _qualityPercent,
        format: CompressFormat.jpeg,
      );

      // Encode to base64
      final base64String = base64Encode(compressedBytes);

      // Size guard — Firestore doc limit is 1MB; we cap at 700KB to leave
      // headroom for the other message fields.
      if (base64String.length > _maxBase64Bytes) {
        onError('Image too large. Please choose a smaller image.');
        return null;
      }

      return base64String;
    } on FileSystemException catch (e) {
      onError('Could not read image: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ImageCompressService error: $e');
      onError('Could not process image. Please try again.');
      return null;
    }
  }

  /// Shows a bottom sheet to let the user choose gallery or camera,
  /// then picks, compresses, and returns the base64 string.
  static Future<String?> showPickerSheet({
    required BuildContext context,
    required void Function(String message) onError,
  }) async {
    ImageSource? chosenSource;

    // Mark picker as opened to prevent PIN prompts
    PinService.markPickerOpened();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Share a Payment Screenshot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFFCF6),
                    child: Icon(Icons.photo_library_outlined,
                        color: Color(0xFF10B981)),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    chosenSource = ImageSource.gallery;
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFFCF6),
                    child: Icon(Icons.camera_alt_outlined,
                        color: Color(0xFF10B981)),
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    chosenSource = ImageSource.camera;
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (chosenSource == null) return null;

    return pickAndEncode(source: chosenSource!, onError: onError);
  }
}
