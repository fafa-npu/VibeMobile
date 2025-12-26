import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/device_provider.dart';
import '../../../data/models/device.dart';

/// Devices management screen.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceProvider.notifier).refresh();
      ref.read(deviceProvider.notifier).connectWebSocket();
    });
  }

  @override
  void dispose() {
    // Don't disconnect WebSocket on screen dispose - it should stay connected
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider);

    // Handle pending pairing request
    if (deviceState.pendingRequest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPairingRequestDialog(context, deviceState.pendingRequest!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(deviceProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pairing Section
          _buildPairingSection(deviceState),

          const Divider(),

          // Device List
          Expanded(
            child: deviceState.isLoading && deviceState.devices.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : deviceState.devices.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: deviceState.devices.length,
                        itemBuilder: (context, index) {
                          return _buildDeviceCard(deviceState.devices[index]);
                        },
                      ),
          ),

          // Error Display
          if (deviceState.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      deviceState.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(deviceProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPairingSection(DeviceListState deviceState) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pair New Device',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a pairing code to connect a new device to VibeMobile.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          if (deviceState.currentPairingCode != null)
            _buildPairingCodeCard(deviceState.currentPairingCode!)
          else
            Center(
              child: FilledButton.icon(
                onPressed: () => ref.read(deviceProvider.notifier).generatePairingCode(),
                icon: const Icon(Icons.add_link),
                label: const Text('Generate Pairing Code'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPairingCodeCard(PairingCode code) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Pairing Code',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              code.code,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Expires in ${code.remainingSeconds} seconds',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(deviceProvider.notifier).cancelPairingCode(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No paired devices',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a pairing code to connect a device',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: device.isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getDeviceIcon(device.browser),
                    color: device.isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            device.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (device.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${device.browser} on ${device.os}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleDeviceAction(device, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'trust_full',
                      child: Text('Full Trust'),
                    ),
                    const PopupMenuItem(
                      value: 'trust_partial',
                      child: Text('Partial Trust'),
                    ),
                    const PopupMenuItem(
                      value: 'trust_view_only',
                      child: Text('View Only'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'revoke',
                      child: Text(
                        'Revoke Device',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip('Trust: ${device.trustLevelDisplay}'),
                const SizedBox(width: 8),
                _buildInfoChip('IP: ${device.ip}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last active: ${dateFormat.format(device.lastActiveAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  IconData _getDeviceIcon(String browser) {
    final lowerBrowser = browser.toLowerCase();
    if (lowerBrowser.contains('chrome')) return Icons.language;
    if (lowerBrowser.contains('safari')) return Icons.apple;
    if (lowerBrowser.contains('firefox')) return Icons.local_fire_department;
    if (lowerBrowser.contains('edge')) return Icons.web;
    return Icons.devices;
  }

  Future<void> _handleDeviceAction(Device device, String action) async {
    switch (action) {
      case 'trust_full':
        await ref.read(deviceProvider.notifier).updateDeviceTrust(device.id, 'full');
        break;
      case 'trust_partial':
        await ref.read(deviceProvider.notifier).updateDeviceTrust(device.id, 'partial');
        break;
      case 'trust_view_only':
        await ref.read(deviceProvider.notifier).updateDeviceTrust(device.id, 'view_only');
        break;
      case 'revoke':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Revoke Device'),
            content: Text('Are you sure you want to revoke "${device.name}"? This device will no longer have access.'),
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
                child: const Text('Revoke'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(deviceProvider.notifier).revokeDevice(device.id);
        }
        break;
    }
  }

  Future<void> _showPairingRequestDialog(BuildContext context, PairingRequest request) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pairing Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A device is requesting to pair:'),
            const SizedBox(height: 16),
            _buildRequestInfo('Device', request.deviceName),
            _buildRequestInfo('Browser', request.browser),
            _buildRequestInfo('OS', request.os),
            _buildRequestInfo('IP', request.ip),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(deviceProvider.notifier).approvePairing(request.approvalId);
    } else {
      await ref.read(deviceProvider.notifier).rejectPairing(request.approvalId);
    }

    ref.read(deviceProvider.notifier).clearPendingRequest();
  }

  Widget _buildRequestInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
