import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/chat_message.dart';
import 'package:expense_tracker/services/chat_service.dart';
import 'package:expense_tracker/services/image_compress_service.dart';
import 'package:expense_tracker/widgets/chat/full_screen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl = '',
  });

  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  late final String _chatId;
  List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _chatId = ChatService.chatId(widget.currentUserId, widget.otherUserId);
    _ensureChatExists();
    _markRead();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureChatExists() async {
    await ChatService.getOrCreateChat(
        widget.currentUserId, widget.otherUserId);
  }

  Future<void> _markRead() async {
    try {
      await ChatService.markChatRead(
        chatId: _chatId,
        userId: widget.currentUserId,
      );
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      if (snap.docs.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        _lastDoc = snap.docs.last;
        final older = snap.docs.map(ChatMessage.fromDoc).toList();
        setState(() => _messages = [..._messages, ...older]);
      }
    } catch (_) {}

    setState(() => _isLoadingMore = false);
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() => _isSending = true);

    try {
      await ChatService.sendTextMessage(
        chatId: _chatId,
        senderId: widget.currentUserId,
        recipientId: widget.otherUserId,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_isSending) return;

    final base64 = await ImageCompressService.showPickerSheet(
      context: context,
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      },
    );

    if (base64 == null || !mounted) return;

    setState(() => _isSending = true);

    try {
      await ChatService.sendImageMessage(
        chatId: _chatId,
        senderId: widget.currentUserId,
        recipientId: widget.otherUserId,
        imageBase64: base64,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F172A),
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Color(0xFF10B981), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          _buildAvatar(widget.otherUserName, widget.otherUserPhotoUrl,
              radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Tap to view profile',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: ChatService.getMessagesStream(_chatId, limit: _pageSize),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _messages.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        // Use stream data as source of truth for latest messages
        final streamMessages = snapshot.data ?? [];

        // Update _lastDoc for pagination
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          // We can't get the doc here from the stream, but we load on demand
        }

        if (streamMessages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: Color(0xFFCBD5E1)),
                SizedBox(height: 16),
                Text(
                  'No messages yet.\nSay hello! 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // newest at bottom
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: streamMessages.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == streamMessages.length) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF10B981))),
              );
            }
            final msg = streamMessages[index];
            final isMine = msg.senderId == widget.currentUserId;
            return _buildMessageBubble(msg, isMine);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _buildAvatar(widget.otherUserName, widget.otherUserPhotoUrl,
                radius: 14),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFF10B981)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: msg.type == 'image'
                      ? _buildImageBubbleContent(msg, isMine)
                      : _buildTextBubbleContent(msg, isMine),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(msg.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.status == 'read'
                            ? Icons.done_all
                            : Icons.done,
                        size: 12,
                        color: msg.status == 'read'
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTextBubbleContent(ChatMessage msg, bool isMine) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        msg.text,
        style: TextStyle(
          color: isMine ? Colors.white : const Color(0xFF0F172A),
          fontSize: 14.5,
        ),
      ),
    );
  }

  Widget _buildImageBubbleContent(ChatMessage msg, bool isMine) {
    if (msg.imageBase64 == null || msg.imageBase64!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
      );
    }

    late final Uint8List bytes;
    try {
      bytes = base64Decode(msg.imageBase64!);
    } catch (_) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.broken_image, size: 40),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(imageBase64: msg.imageBase64!),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        child: Image.memory(
          bytes,
          width: 220,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.broken_image, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      child: Row(
        children: [
          // Image attach button
          Material(
            color: const Color(0xFFEFFCF6),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isSending ? null : _sendImage,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.image_outlined,
                    color: Color(0xFF10B981), size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          Material(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isSending ? null : _sendText,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, String photoUrl, {double radius = 20}) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hue = (name.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.5, 0.45).toColor();

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('h:mm a').format(dt);
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
