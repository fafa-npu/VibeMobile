import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/logs_provider.dart';

/// Logs screen for viewing application logs.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(logsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(logsProvider);

    // Auto-scroll when new logs arrive
    if (logsState.autoScroll && logsState.logs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // Filter Dropdown
          PopupMenuButton<LogLevel>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (level) {
              ref.read(logsProvider.notifier).setFilter(level);
            },
            itemBuilder: (context) => [
              _buildFilterItem(LogLevel.all, 'All', logsState.filter),
              _buildFilterItem(LogLevel.debug, 'Debug+', logsState.filter),
              _buildFilterItem(LogLevel.info, 'Info+', logsState.filter),
              _buildFilterItem(LogLevel.warning, 'Warning+', logsState.filter),
              _buildFilterItem(LogLevel.error, 'Error', logsState.filter),
            ],
          ),
          // Auto-scroll toggle
          IconButton(
            icon: Icon(
              logsState.autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
            ),
            tooltip: logsState.autoScroll ? 'Auto-scroll: ON' : 'Auto-scroll: OFF',
            onPressed: () {
              ref.read(logsProvider.notifier).setAutoScroll(!logsState.autoScroll);
            },
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(logsProvider.notifier).refresh();
            },
          ),
          // Clear
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter indicator
          if (logsState.filter != LogLevel.all)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Showing: ${_getFilterLabel(logsState.filter)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(logsProvider.notifier).setFilter(LogLevel.all);
                    },
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
            ),

          // Log List
          Expanded(
            child: logsState.filteredLogs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: logsState.filteredLogs.length,
                    itemBuilder: (context, index) {
                      return _buildLogEntry(logsState.filteredLogs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<LogLevel> _buildFilterItem(
    LogLevel level,
    String label,
    LogLevel currentFilter,
  ) {
    return PopupMenuItem<LogLevel>(
      value: level,
      child: Row(
        children: [
          if (level == currentFilter)
            const Icon(Icons.check, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  String _getFilterLabel(LogLevel filter) {
    switch (filter) {
      case LogLevel.all:
        return 'All';
      case LogLevel.debug:
        return 'Debug and above';
      case LogLevel.info:
        return 'Info and above';
      case LogLevel.warning:
        return 'Warning and above';
      case LogLevel.error:
        return 'Errors only';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No logs',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Logs will appear here as the app runs',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(LogEntry entry) {
    final color = _getLogColor(entry.level);
    final timeStr = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          // Level badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              entry.level,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Message
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR':
      case 'FATAL':
        return Colors.red;
      case 'WARN':
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
        return Colors.blue;
      case 'DEBUG':
        return Colors.grey;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(logsProvider.notifier).clearLogs();
    }
  }
}
