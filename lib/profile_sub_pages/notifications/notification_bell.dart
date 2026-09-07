// =============================================================================
// notification_bell.dart
//
// Drop this into any AppBar's `actions: []`. Shows a bell icon with an
// unread-count badge; tapping it opens a small Upwork-style dropdown panel
// with the most recent notifications and a "See all" button that pushes the
// full NotificationsScreen.
//
// USAGE:
//   AppBar(
//     actions: [ NotificationBell(), SizedBox(width: 8) ],
//   )
// =============================================================================

import 'package:flutter/material.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_model.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_service.dart';  
import 'package:ali_app/profile_sub_pages/notifications/notifications_screen.dart';  


const _amber = Color(0xFFC9A227);
const _border = Color(0xFFE3E0D5);
const _white = Color(0xFFFFFFFF);
const _textPri = Color(0xFF0E3B2E);
const _textSec = Color(0xFF5D6B64);

class NotificationBell extends StatefulWidget {
  /// Icon color — pass Colors.white when the bell sits on a dark
  /// (navy/emerald) AppBar, or leave default for light surfaces.
  final Color iconColor;
  const NotificationBell({super.key, this.iconColor = _textPri});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  void _toggleDropdown() {
    if (_overlay != null) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final overlayState = Overlay.of(context);
    _overlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap-outside-to-close scrim
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeDropdown,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(-260, 44),
            child: _DropdownPanel(onSeeAll: () {
              _closeDropdown();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            }),
          ),
        ],
      ),
    );
    overlayState.insert(_overlay!);
  }

  void _closeDropdown() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: StreamBuilder<int>(
        stream: NotificationService.instance.streamUnreadCount(),
        builder: (context, snap) {
          final count = snap.data ?? 0;
          return IconButton(
            onPressed: _toggleDropdown,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined, color: widget.iconColor),
                if (count > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _white, width: 1.5),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DropdownPanel extends StatelessWidget {
  final VoidCallback onSeeAll;
  const _DropdownPanel({required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: _white,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Notifications',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _textPri)),
                  ),
                  TextButton(
                    onPressed: () =>
                        NotificationService.instance.markAllAsRead(),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Mark all read',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _amber)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: StreamBuilder<List<NotificationModel>>(
                stream: NotificationService.instance.streamRecent(limit: 8),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _amber))),
                    );
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text('No notifications yet',
                            style: TextStyle(fontSize: 12.5, color: _textSec)),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: _border),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      return InkWell(
                        onTap: () {
                          if (!n.isRead) {
                            NotificationService.instance.markAsRead(n.id);
                          }
                        },
                        child: Container(
                          color: n.isRead
                              ? Colors.transparent
                              : n.color.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: n.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(n.icon, size: 16, color: n.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(n.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: n.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            color: _textPri)),
                                    const SizedBox(height: 2),
                                    Text(n.message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            color: _textSec,
                                            height: 1.3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1, color: _border),
            InkWell(
              onTap: onSeeAll,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('See all notifications',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _amber)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}