import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ali_app/MessageAndNotification/chat_meta_service.dart';
import 'package:ali_app/MessageAndNotification/chat_service.dart';
import 'package:ali_app/MessageAndNotification/chat_screen.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_service.dart';
import 'package:ali_app/MessageAndNotification/chat_meta.dart';

// ── Design tokens ─────────────────────────────────────────────
const _navy = Color(0xFF0E3B2E);
const _navyMid = Color(0xFF1A5C46);
const _amber = Color(0xFFC9A227);
const _amberDark = Color(0xFFA8861D);
const _amberLight = Color(0xFFFBF6E3);
const _bg = Color(0xFFF7F5EF);
const _surface = Colors.white;
const _textPri = Color(0xFF1F2A26);
const _textSec = Color(0xFF5D6B64);
const _textFaint = Color(0xFFA6B2AB);
const _border = Color(0xFFE3E0D5);
const _success = Color(0xFF10B981);

class ConversationsInboxScreen extends StatelessWidget {
  const ConversationsInboxScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserRole, // 'client' or 'contractor'
    required this.cloudinaryService,
  });

  final String currentUserId;
  final String currentUserRole;
  final CloudinaryService cloudinaryService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Custom gradient header ───────────────────────────
          _buildHeader(context),

          // ── Conversation list ────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ChatMeta>>(
              stream: ChatMetaService.watchInbox(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(error: snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _navy),
                  );
                }

                final chats = snapshot.data!;
                if (chats.isEmpty) return const _EmptyState();

                // Compute total unread
                final totalUnread = chats.fold<int>(
                  0,
                  (sum, c) => sum + c.unreadCountFor(currentUserId),
                );

                return Column(
                  children: [
                    // Subtle stats bar
                    _buildStatsBar(chats.length, totalUnread),

                    // List
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: chats.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 80,
                          color: _border,
                        ),
                        itemBuilder: (_, i) => _ConversationTile(
                          meta: chats[i],
                          currentUserId: currentUserId,
                          onTap: () => _openChat(context, chats[i]),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 20, 20),
          child: Column(
            children: [
              // Top row: back + title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chat_bubble_rounded,
                      color: _amber, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  // Total unread badge
                  StreamBuilder<List<ChatMeta>>(
                    stream: ChatMetaService.watchInbox(currentUserId),
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final total = snap.data!.fold<int>(
                        0,
                        (s, c) => s + c.unreadCountFor(currentUserId),
                      );
                      if (total == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _amber,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          total > 99 ? '99+' : '$total',
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats bar ───────────────────────────────────────────────
  Widget _buildStatsBar(int count, int unread) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: _surface,
      child: Row(
        children: [
          Icon(Icons.forum_outlined, size: 15, color: _textSec),
          const SizedBox(width: 6),
          Text(
            '$count conversation${count == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              color: _textSec,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: _textFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$unread unread',
              style: const TextStyle(
                fontSize: 12,
                color: _amber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openChat(BuildContext context, ChatMeta meta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          jobId: meta.jobId,
          currentUserId: currentUserId,
          otherPartyName: meta.otherPartyName(currentUserId),
          otherPartyPhotoUrl: meta.otherPartyPhotoUrl(currentUserId),
          chatService: ChatService(
            jobId: meta.jobId,
            cloudinaryService: cloudinaryService,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONVERSATION TILE — redesigned
// ═══════════════════════════════════════════════════════════════
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.meta,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatMeta meta;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unreadCount = meta.unreadCountFor(currentUserId);
    final hasUnread = unreadCount > 0;
    final isMineLastMsg = meta.lastSenderId == currentUserId;
    final otherName = meta.otherPartyName(currentUserId);
    final otherPhoto = meta.otherPartyPhotoUrl(currentUserId);
    final hasPhoto = otherPhoto?.isNotEmpty ?? false;
    final initials = _initials(otherName);
    final isActive = meta.jobStatus == 'active';

    return Material(
      color: hasUnread ? const Color(0xFFF0EDE4) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _navy.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Avatar with online ring ──────────────────────
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? _success : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 27,
                      backgroundColor: _navy,
                      backgroundImage:
                          hasPhoto ? NetworkImage(otherPhoto!) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _success,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // ── Content ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: _navy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(meta.lastMessageTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: hasUnread ? _amberDark : _textFaint,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Job title chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _amberLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meta.jobTitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _amberDark,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Last message + unread
                    Row(
                      children: [
                        if (isMineLastMsg && meta.lastMessage.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(Icons.done_all_rounded,
                                size: 14, color: _textFaint),
                          ),
                        Expanded(
                          child: Text(
                            meta.lastMessage.isEmpty
                                ? 'Conversation started'
                                : isMineLastMsg
                                    ? meta.lastMessage
                                    : meta.lastMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread ? _textPri : _textSec,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontStyle: meta.lastMessage.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_amber, _amberDark],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(time);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(time);
    return DateFormat('d MMM').format(time);
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 56,
                color: _amber,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Once a client accepts your bid or you hire\na contractor, conversations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _textSec,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _amberLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: _amberDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: Quick responses build trust and\nincrease your chance of getting hired.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSec,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ERROR STATE
// ═══════════════════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Couldn\'t load messages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _textSec),
            ),
          ],
        ),
      ),
    );
  }
}
