import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/session.dart';

/// Session list widget.
class SessionList extends StatelessWidget {
  final List<Session> sessions;
  final Function(String) onAttach;
  final Function(String) onKill;

  const SessionList({
    super.key,
    required this.sessions,
    required this.onAttach,
    required this.onKill,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sessions.map((session) => _buildSessionCard(context, session)).toList(),
    );
  }

  Widget _buildSessionCard(BuildContext context, Session session) {
    final dateFormat = DateFormat('MM/dd HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.terminal,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          session.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (session.workingDir != null)
              Text(
                session.workingDir!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              'Created: ${dateFormat.format(session.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Attach',
              onPressed: () => onAttach(session.id),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Kill',
              onPressed: () => _confirmKill(context, session),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _confirmKill(BuildContext context, Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kill Session'),
        content: Text('Are you sure you want to kill "${session.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Kill'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onKill(session.id);
    }
  }
}
