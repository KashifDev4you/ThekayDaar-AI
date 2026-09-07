// lib/widgets/nic_thumb.dart
import 'package:flutter/material.dart';
import 'nic_viewer_sheet.dart';

class NicThumbRow extends StatelessWidget {
  final String? frontUrl;
  final String? backUrl;

  const NicThumbRow({super.key, this.frontUrl, this.backUrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Thumb(
          url: frontUrl,
          label: 'Front',
          onTap: () => NicViewerSheet.show(
            context,
            frontUrl: frontUrl,
            backUrl: backUrl,
            startIndex: 0,
          ),
        ),
        const SizedBox(width: 10),
        _Thumb(
          url: backUrl,
          label: 'Back',
          onTap: () => NicViewerSheet.show(
            context,
            frontUrl: frontUrl,
            backUrl: backUrl,
            startIndex: 1,
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final String label;
  final VoidCallback onTap;

  const _Thumb({
    required this.url,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: url != null ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA6B2AB),
                        fontWeight: FontWeight.w500)),
                if (url == null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.warning_amber_rounded,
                      size: 11, color: Color(0xFFC9A227)),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Stack(
              children: [
                Container(
                  height: 88,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE3E0D5)),
                    image: url != null
                        ? DecorationImage(
                            image: NetworkImage(url!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: url == null
                      ? const Center(
                          child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFFA9B5AE),
                              size: 26))
                      : null,
                ),
                // Zoom icon overlay
                if (url != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}