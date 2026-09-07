import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ali_app/MessageAndNotification/chat_message.dart';
import 'package:ali_app/MessageAndNotification/chat_service.dart';
import 'package:ali_app/MessageAndNotification/chat_meta_service.dart';
import 'package:ali_app/services/gemini_service.dart';
import 'package:ali_app/utils/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.jobId,
    required this.currentUserId,
    required this.otherPartyName,
    required this.chatService,
    this.otherPartyPhotoUrl,
    this.onAvatarTap,
  });

  final String jobId;
  final String currentUserId;
  final String otherPartyName;
  final ChatService chatService;

  /// URL of the other party's profile photo. Null or empty falls back to
  /// an initials avatar.
  final String? otherPartyPhotoUrl;

  /// Called when the avatar/name in the header is tapped — wire this to
  /// navigate to the other party's profile screen. If null, the header
  /// is not tappable.
  final VoidCallback? onAvatarTap;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();
  bool _isSendingImage = false;

  static const _navy = Color(0xFF0E3B2E);
  static const _navyMid = Color(0xFF1A5C46);
  static const _bg = AppTheme.bg;
  static const _mineBubble = Color(0xFF0E3B2E);
  static const _theirsBubble = Colors.white;
  static const _amber = Color(0xFFC9A227);
  static const _textSec = Color(0xFF5D6B64);

  @override
  void initState() {
    super.initState();
    // Mark incoming messages as seen, and clear this user's unread badge.
    widget.chatService.markMessagesSeen(widget.currentUserId);
    ChatMetaService.markRead(widget.jobId, widget.currentUserId);
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    await widget.chatService.sendText(
      senderId: widget.currentUserId,
      text: text,
    );
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isSendingImage = true);
    try {
      await widget.chatService.sendImage(
        senderId: widget.currentUserId,
        imageFile: File(picked.path),
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Groups messages with date separators inserted, WhatsApp-style.
  List<_ChatListItem> _buildItems(List<ChatMessage> messages) {
    final items = <_ChatListItem>[];
    DateTime? lastDate;
    for (final m in messages) {
      final d = DateTime(m.timestamp.year, m.timestamp.month, m.timestamp.day);
      if (lastDate == null || d != lastDate) {
        items.add(_ChatListItem.date(d));
        lastDate = d;
      }
      items.add(_ChatListItem.message(m));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.otherPartyPhotoUrl?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_navy, _navyMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  InkWell(
                    onTap: widget.onAvatarTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white24,
                            backgroundImage: hasPhoto
                                ? CachedNetworkImageProvider(
                                    widget.otherPartyPhotoUrl!)
                                : null,
                            child: hasPhoto
                                ? null
                                : Text(
                                    widget.otherPartyName.isNotEmpty
                                        ? widget.otherPartyName[0]
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.otherPartyName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Tap to view profile',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.chatService.watchMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Couldn\'t load messages: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _navy.withValues(alpha: 0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: _amber,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Start the conversation',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hello and discuss the project \ud83d\udc4b',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textSec,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mark new incoming messages seen while the chat is open.
                widget.chatService.markMessagesSeen(widget.currentUserId);

                final items = _buildItems(messages);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.isDate) {
                      return _DateSeparator(date: item.date!);
                    }
                    final message = item.message!;
                    final isMine = message.senderId == widget.currentUserId;

                    // Look at the previous list item to decide grouping —
                    // same sender, no date break in between → tighter spacing,
                    // no repeated name label (Upwork-style message clusters).
                    final prevItem = index > 0 ? items[index - 1] : null;
                    final isGrouped = prevItem != null &&
                        !prevItem.isDate &&
                        prevItem.message!.senderId == message.senderId;

                    return _MessageBubble(
                      message: message,
                      isMine: isMine,
                      mineColor: _mineBubble,
                      theirsColor: _theirsBubble,
                      isGrouped: isGrouped,
                      senderLabel: isMine ? 'You' : widget.otherPartyName,
                    );
                  },
                );
              },
            ),
          ),
          if (_isSendingImage) const LinearProgressIndicator(minHeight: 2),
          _SmartReplyPanel(
            chatService: widget.chatService,
            currentUserId: widget.currentUserId,
            otherPartyName: widget.otherPartyName,
            controller: _textController,
          ),
          _InputBar(
            controller: _textController,
            onSend: _sendText,
            onPickGallery: () => _pickAndSendImage(ImageSource.gallery),
            onPickCamera: () => _pickAndSendImage(ImageSource.camera),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Helper item type for date-separated list
// ─────────────────────────────────────────────────────────────────
class _ChatListItem {
  final DateTime? date;
  final ChatMessage? message;
  _ChatListItem._({this.date, this.message});
  factory _ChatListItem.date(DateTime d) => _ChatListItem._(date: d);
  factory _ChatListItem.message(ChatMessage m) => _ChatListItem._(message: m);
  bool get isDate => date != null;
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppTheme.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.emeraldSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                _label(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0E3B2E),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppTheme.border)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Smart reply panel
// ─────────────────────────────────────────────────────────────────
class _SmartReplyPanel extends StatefulWidget {
  const _SmartReplyPanel({
    required this.chatService,
    required this.currentUserId,
    required this.otherPartyName,
    required this.controller,
  });

  final ChatService chatService;
  final String currentUserId;
  final String otherPartyName;
  final TextEditingController controller;

  @override
  State<_SmartReplyPanel> createState() => _SmartReplyPanelState();
}

class _SmartReplyPanelState extends State<_SmartReplyPanel> {
  List<String> _replies = [];
  bool _loading = false;

  void _clear() {
    if (_replies.isNotEmpty || _loading) {
      setState(() {
        _replies = [];
        _loading = false;
      });
    }
  }

  Future<void> _generate(List<ChatMessage> messages) async {
    final lines = messages
        .where((m) => m.text?.trim().isNotEmpty == true)
        .map((m) {
          final sender = m.senderId == widget.currentUserId ? 'Me' : widget.otherPartyName;
          return '$sender: ${m.text}';
        })
        .toList();
    if (lines.isEmpty) return;

    setState(() => _loading = true);
    try {
      final replies = await GeminiService.suggestChatReplies(
        recentMessageLines: lines,
        otherPartyName: widget.otherPartyName,
      );
      if (!mounted) return;
      setState(() => _replies = replies);
    } catch (e) {
      if (!mounted) return;
      setState(() => _replies = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: widget.chatService.watchMessages(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final messages = snapshot.data!;
        final lastIsMine = messages.last.senderId == widget.currentUserId;
        if (lastIsMine) _clear();
        if (lastIsMine) return const SizedBox.shrink();

        if (_replies.isEmpty) {
          return Container(
            color: const Color(0xFFF7F5EF),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _loading ? null : () => _generate(messages),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBF6E3), Color(0xFFF5E6CA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFC9A227).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: Color(0xFFC9A227)),
                      const SizedBox(width: 6),
                      Text(
                        _loading ? 'Thinking…' : 'AI Smart Reply',
                        style: const TextStyle(
                          color: Color(0xFF0E3B2E),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          color: const Color(0xFFF7F5EF),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _replies.map((r) {
                    return ActionChip(
                      label: Text(
                        r,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF0E3B2E)),
                      ),
                      backgroundColor: const Color(0xFFFBF6E3),
                      side: const BorderSide(color: Color(0xFFC9A227)),
                      onPressed: () {
                        widget.controller.text = r;
                        widget.controller.selection = TextSelection.collapsed(offset: r.length);
                      },
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF5D6B64)),
                onPressed: _clear,
                tooltip: 'Dismiss',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.image_outlined,
                          color: Color(0xFF5D6B64), size: 22),
                      onPressed: onPickGallery,
                      tooltip: 'Choose photo',
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 5,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1F2A26),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          hintStyle: TextStyle(
                              color: Color(0xFFA6B2AB), fontSize: 14),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 14),
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined,
                          color: Color(0xFF5D6B64), size: 22),
                      onPressed: onPickCamera,
                      tooltip: 'Take photo',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E3B2E), Color(0xFF1A5C46)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0E3B2E).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
                onPressed: onSend,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Message bubble with ticks + clickable links
// ─────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.mineColor,
    required this.theirsColor,
    required this.isGrouped,
    required this.senderLabel,
  });

  final ChatMessage message;
  final bool isMine;
  final Color mineColor;
  final Color theirsColor;
  final bool isGrouped;
  final String senderLabel;

  static final _urlRegex = RegExp(
    r'((https?:\/\/)|(www\.))[^\s]+',
    caseSensitive: false,
  );

  Future<void> _openLink(String url) async {
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Builds text spans, turning URLs into tappable links.
  List<InlineSpan> _buildTextSpans(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    int start = 0;
    final linkColor = isMine ? const Color(0xFFE7C55A) : AppTheme.emeraldMid;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _openLink(url),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment =
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleDecoration = BoxDecoration(
      gradient: isMine
          ? const LinearGradient(
              colors: [Color(0xFF0E3B2E), Color(0xFF1A5C46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isMine ? null : Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMine ? 18 : 4),
        bottomRight: Radius.circular(isMine ? 4 : 18),
      ),
      border: isMine ? null : Border.all(color: AppTheme.border),
      boxShadow: [
        BoxShadow(
          color: isMine
              ? const Color(0xFF0E3B2E).withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: isGrouped ? 4 : 18, bottom: 2),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          // Sender name label — only shown at the start of a new cluster,
          // Upwork-style, so consecutive messages don't repeat it.
          if (!isGrouped)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
              child: Text(
                senderLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D6B64),
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: bubbleDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  message.type == 'image'
                      ? _ImageBubbleContent(message: message, isMine: isMine)
                      : RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: isMine
                                  ? Colors.white
                                  : const Color(0xFF1F2A26),
                              fontSize: 14.5,
                              height: 1.5,
                            ),
                            children: _buildTextSpans(context, message.text ?? ''),
                          ),
                        ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.6)
                              : const Color(0xFFA6B2AB),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.seen ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 14,
                          color: message.seen
                              ? const Color(0xFFC9A227)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageBubbleContent extends StatelessWidget {
  const _ImageBubbleContent({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: message.imageUrl ?? ''),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: message.imageUrl ?? '',
              width: 220,
              height: 150,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox(
                width: 220,
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const SizedBox(
                width: 220,
                height: 150,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        if (message.caption != null && message.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message.caption!,
              style: TextStyle(
                color: isMine ? Colors.white : const Color(0xFF1F2A26),
              ),
            ),
          ),
      ],
    );
  }
}