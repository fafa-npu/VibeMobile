import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/session.dart';
import 'status_indicator.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onConnect;
  final VoidCallback onKill;

  const SessionCard({
    super.key,
    required this.session,
    required this.onConnect,
    required this.onKill,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MM-dd HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: session.isActive
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onConnect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: session.isActive
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.terminal,
                        size: 20,
                        color: session.isActive
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                session.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusIndicator(isActive: session.isActive, size: 8),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(session.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          context,
                          icon: Icons.open_in_new,
                          tooltip: '在终端中打开',
                          onTap: onConnect,
                          isPrimary: true,
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          context,
                          icon: Icons.close,
                          tooltip: '关闭会话',
                          onTap: onKill,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),

                // Working directory
                if (session.workingDir != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.workingDir!,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: colorScheme.onSurface.withOpacity(0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor;
    Color iconColor;

    if (isDestructive) {
      bgColor = colorScheme.errorContainer.withOpacity(0.5);
      iconColor = colorScheme.error;
    } else if (isPrimary) {
      bgColor = colorScheme.primaryContainer;
      iconColor = colorScheme.onPrimaryContainer;
    } else {
      bgColor = colorScheme.surfaceContainerHighest;
      iconColor = colorScheme.onSurface;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
