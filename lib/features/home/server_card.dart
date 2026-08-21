import 'package:flutter/material.dart';

import '../../core/models/server.dart';
import '../../ui/common/theme.dart';

class ServerCard extends StatelessWidget {
  const ServerCard({
    super.key,
    required this.server,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
    this.testing = false,
  });

  final Server server;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool compact;
  final bool testing;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ListTile(
        title: Text(server.name),
        subtitle: Text('${server.username}@${server.host}:${server.port}'),
        leading: const Icon(Icons.dns_outlined, color: AppColors.blue40),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }

    return Card(
      elevation: 0,
      color: AppColors.blue95,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.dns_outlined, color: AppColors.blue40),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      server.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Text(
                '${server.username}@${server.host}:${server.port}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}