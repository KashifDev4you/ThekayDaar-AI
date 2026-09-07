// =============================================================================
// notifications_screen.dart
//
// Full notifications screen — Upwork-style: grouped by day, unread dot,
// swipe to delete, "mark all as read" action, tap to navigate based on type.
// Backed entirely by NotificationService (server-created docs).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_model.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_service.dart';

const _amber = Color(0xFFC9A227);
const _border = Color(0xFFE3E0D5);
const _surface = Color(0xFFF7F5EF);
const _white = Color(0xFFFFFFFF);
const _textPri = Color(0xFF0E3B2E);
const _textSec = Color(0xFF5D6B64);

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPri, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: _textPri)),
        actions: [
          TextButton(
            onPressed: () => NotificationService.instance.markAllAsRead(),
            child: const Text('Mark all read',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _amber)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService.instance.streamNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _amber));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return _EmptyState();
          }

          final groups = _groupByDay(all);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final group = groups[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      group.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _textSec,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  ...group.items.map((n) => _NotificationTile(n: n)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<_DayGroup> _groupByDay(List<NotificationModel> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <NotificationModel>[];
    final yesterdayItems = <NotificationModel>[];
    final earlierItems = <NotificationModel>[];

    for (final n in items) {
      final c = n.createdAt;
      if (c == null) {
        earlierItems.add(n);
        continue;
      }
      final day = DateTime(c.year, c.month, c.day);
      if (day == today) {
        todayItems.add(n);
      } else if (day == yesterday) {
        yesterdayItems.add(n);
      } else {
        earlierItems.add(n);
      }
    }

    final groups = <_DayGroup>[];
    if (todayItems.isNotEmpty) groups.add(_DayGroup('TODAY', todayItems));
    if (yesterdayItems.isNotEmpty) {
      groups.add(_DayGroup('YESTERDAY', yesterdayItems));
    }
    if (earlierItems.isNotEmpty) groups.add(_DayGroup('EARLIER', earlierItems));
    return groups;
  }
}

class _DayGroup {
  final String label;
  final List<NotificationModel> items;
  _DayGroup(this.label, this.items);
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel n;
  const _NotificationTile({required this.n});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: _white),
      ),
      onDismissed: (_) => NotificationService.instance.delete(n.id),
      child: InkWell(
        onTap: () {
          if (!n.isRead) NotificationService.instance.markAsRead(n.id);
          _handleTap(context, n);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: n.isRead ? _white : n.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: n.isRead ? _border : n.color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: n.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(n.icon, color: n.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  n.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: _textPri,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6, top: 2),
                            decoration: BoxDecoration(
                              color: n.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.message,
                      style: const TextStyle(fontSize: 12.5, color: _textSec, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(n.createdAt),
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFFA6B2AB)),
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

  void _handleTap(BuildContext context, NotificationModel n) {
    // Wire these up to your real routes once they exist:
    switch (n.type) {
      case NotificationType.chatMessage:
        // e.g. Navigator.push(context, MaterialPageRoute(builder: (_) =>
        //   ChatScreen(chatId: n.data['chatId'])));
        break;
      case NotificationType.planActivated:
      case NotificationType.paymentApproved:
      case NotificationType.paymentRejected:
        // e.g. push BillingScreen
        break;
      case NotificationType.contractUpdate:
        // e.g. push ContractDetailScreen(contractId: n.data['contractId'])
        break;
      default:
        break;
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 36, color: _textSec),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _textPri)),
          const SizedBox(height: 6),
          const Text(
            'Account activity — chats, plan updates,\nand security alerts — will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _textSec, height: 1.5),
          ),
        ],
      ),
    );
  }
}