import 'package:flutter/material.dart';

class StatusPanel extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Widget? action;
  const StatusPanel({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color = Colors.orange,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(height: 1.5))),
          ],
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: action),
      ],
    ),
  );
}
