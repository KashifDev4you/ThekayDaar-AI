// lib/widgets/nic_viewer_sheet.dart
import 'package:flutter/material.dart';

class NicViewerSheet extends StatefulWidget {
  final String? frontUrl;
  final String? backUrl;
  final int startIndex;

  const NicViewerSheet({
    super.key,
    this.frontUrl,
    this.backUrl,
    this.startIndex = 0,
  });

  // Static helper — call this from anywhere
  static void show(
    BuildContext context, {
    String? frontUrl,
    String? backUrl,
    int startIndex = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => NicViewerSheet(
        frontUrl: frontUrl,
        backUrl: backUrl,
        startIndex: startIndex,
      ),
    );
  }

  @override
  State<NicViewerSheet> createState() => _NicViewerSheetState();
}

class _NicViewerSheetState extends State<NicViewerSheet>
    with SingleTickerProviderStateMixin {
  late int _selected;
  late final TransformationController _transformCtrl;
  late final AnimationController _resetAnim;
  Animation<Matrix4>? _resetMatrix;

  @override
  void initState() {
    super.initState();
    _selected     = widget.startIndex;
    _transformCtrl = TransformationController();
    _resetAnim    = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_resetMatrix != null) {
          _transformCtrl.value = _resetMatrix!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _resetAnim.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_selected == index) return;
    // Reset zoom when switching tabs
    _transformCtrl.value = Matrix4.identity();
    setState(() => _selected = index);
  }

  void _resetZoom() {
    _resetMatrix = Matrix4Tween(
      begin: _transformCtrl.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _resetAnim,
      curve: Curves.easeOut,
    ));
    _resetAnim.forward(from: 0);
  }

  String? get _activeUrl =>
      _selected == 0 ? widget.frontUrl : widget.backUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ───────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.credit_card_rounded,
                      color: Colors.white70, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('NIC Document',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                // Reset zoom button
                if (_activeUrl != null)
                  GestureDetector(
                    onTap: _resetZoom,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.zoom_out_map_rounded,
                          color: Colors.white60, size: 16),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Tab switcher ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _NicTab(
                    label: 'Front Side',
                    icon: Icons.flip_to_front_rounded,
                    selected: _selected == 0,
                    hasImage: widget.frontUrl != null,
                    onTap: () => _switchTab(0),
                  ),
                  const SizedBox(width: 3),
                  _NicTab(
                    label: 'Back Side',
                    icon: Icons.flip_to_back_rounded,
                    selected: _selected == 1,
                    hasImage: widget.backUrl != null,
                    onTap: () => _switchTab(1),
                  ),
                ],
              ),
            ),
          ),

          // ── Image area ───────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: _activeUrl != null
                    ? _ZoomableImage(
                        key: ValueKey(_selected),
                        url: _activeUrl!,
                        controller: _transformCtrl,
                      )
                    : _EmptyState(
                        key: ValueKey('empty_$_selected'),
                        label: _selected == 0
                            ? 'Front image not uploaded'
                            : 'Back image not uploaded',
                      ),
              ),
            ),
          ),

          // ── Hint ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pinch_outlined,
                    size: 13, color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(width: 5),
                Text('Pinch to zoom  •  Tap tabs to switch',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zoomable image ─────────────────────────────────────────────
class _ZoomableImage extends StatelessWidget {
  final String url;
  final TransformationController controller;

  const _ZoomableImage({
    super.key,
    required this.url,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InteractiveViewer(
        transformationController: controller,
        minScale: 0.8,
        maxScale: 6.0,
        clipBehavior: Clip.none,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            final pct = progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded /
                    progress.expectedTotalBytes!
                : null;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: pct,
                      color: const Color(0xFFC9A227),
                      strokeWidth: 2.5,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  if (pct != null) ...[
                    const SizedBox(height: 10),
                    Text('${(pct * 100).toInt()}%',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12)),
                  ],
                ],
              ),
            );
          },
          errorBuilder: (_, _, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.white.withValues(alpha: 0.2), size: 52),
                const SizedBox(height: 10),
                Text('Could not load image',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.image_not_supported_outlined,
                color: Colors.white.withValues(alpha: 0.2), size: 32),
          ),
          const SizedBox(height: 14),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Tab button ─────────────────────────────────────────────────
class _NicTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool hasImage;
  final VoidCallback onTap;

  const _NicTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.hasImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? Colors.white : Colors.white38)),
              if (!hasImage) ...[
                const SizedBox(width: 5),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC9A227),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}