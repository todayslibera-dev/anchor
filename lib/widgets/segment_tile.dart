import 'package:flutter/material.dart';

import '../data.dart';
import '../utils.dart';

class SegmentTile extends StatelessWidget {
  const SegmentTile({
    super.key,
    required this.segment,
    required this.currentPosition,
    required this.onTapSegment,
    required this.theme,
  });

  final DemoSegment segment;
  final Duration currentPosition;
  final VoidCallback onTapSegment;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isActive = currentPosition >= segment.timestamp &&
        currentPosition <= segment.endTimestamp;
    final backgroundColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;

    return InkWell(
      onTap: onTapSegment,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(segment.speakerLabel),
                ),
                const SizedBox(width: 12),
                Text(
                  formatTimestamp(segment.timestamp),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(segment.text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
