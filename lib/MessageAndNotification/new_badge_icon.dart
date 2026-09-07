import 'package:flutter/material.dart';
import 'package:ali_app/MessageAndNotification/chat_meta_service.dart';

/// Wraps any nav icon and overlays a red "1, 2, 3..." badge showing
/// the user's total unread message count across all conversations.
/// Usage: NavBadgeIcon(userId: _uid, icon: Icon(Icons.chat_bubble_outline_rounded))
class NavBadgeIcon extends StatelessWidget {
  const NavBadgeIcon({super.key, required this.userId, required this.icon});

  final String userId;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return icon;

    return StreamBuilder<int>(
      stream: ChatMetaService.watchTotalUnread(userId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            if (count > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}