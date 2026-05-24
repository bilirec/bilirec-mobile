import 'package:flutter/material.dart';

class ServiceStatusRow extends StatelessWidget {
  const ServiceStatusRow({
    required this.statusColor,
    required this.statusText,
    super.key,
  });

  final Color statusColor;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.shield, color: statusColor),
        const SizedBox(width: 8),
        Expanded(child: Text(statusText)),
      ],
    );
  }
}
