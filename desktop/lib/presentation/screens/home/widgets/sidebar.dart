import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/device.dart';
import '../../../providers/server_provider.dart';
import '../../../providers/tunnel_provider.dart';
import '../../../providers/device_provider.dart';
import '../../../providers/settings_provider.dart';

/// Sidebar widget for the new layout.
/// Contains QR code preview, connection status, device list, and server controls.
class Sidebar extends ConsumerWidget {
  final VoidCallback onQRTap;
  final VoidCallback onToggleService;

  const Sidebar({
    super.key,
    required this.onQRTap,
    required this.onToggleService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverProvider);
    final tunnelState = ref.watch(tunnelProvider);
    final deviceState = ref.watch(deviceProvider);
    final settings = ref.watch(settingsProvider);

    final bool hasDevices = deviceState.devices.isNotEmpty;

    return Container(
      width: AppColors.sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.bgSidebar,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // QR Code quick connect card - only show when no devices
          if (!hasDevices) _buildQRCard(context, tunnelState),

          // Connection status
          _buildConnectionStatus(context, serverState, tunnelState, settings.apiPort),

          // Device list
          Expanded(
            child: _buildDeviceList(context, deviceState, ref, hasDevices),
          ),

          // Server controls
          _buildServerControls(context, serverState, tunnelState),
        ],
      ),
    );
  }

  Widget _buildQRCard(BuildContext context, TunnelState tunnelState) {
    final bool hasUrl = tunnelState.publicUrl != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: onQRTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppColors.radiusMedium),
            boxShadow: AppColors.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onQRTap,
              borderRadius: BorderRadius.circular(AppColors.radiusMedium),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // QR code preview
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: hasUrl
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: QrImageView(
                                data: tunnelState.publicUrl!,
                                version: QrVersions.auto,
                                size: 72,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(4),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.qr_code_2,
                                size: 48,
                                color: AppColors.textSecondary.withOpacity(0.3),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    // Label
                    Text(
                      '扫码连接',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasUrl ? '点击展开' : '启动 Tunnel 后可用',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(
    BuildContext context,
    ServerState serverState,
    TunnelState tunnelState,
    int apiPort,
  ) {
    final bool isOnline = serverState.isRunning && tunnelState.isConnected;
    final String statusText = isOnline
        ? '服务已启动'
        : serverState.isRunning
            ? '服务运行中 (无 Tunnel)'
            : '服务未启动';
    final String metaText = serverState.isRunning
        ? 'localhost:$apiPort'
        : '点击下方按钮启动';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline
                  ? AppColors.success
                  : serverState.isRunning
                      ? AppColors.warning
                      : AppColors.textSecondary,
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  metaText,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, DeviceListState deviceState, WidgetRef ref, bool hasDevices) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '已连接设备',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ref.read(deviceProvider.notifier).refresh(),
                    child: Icon(
                      Icons.refresh,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Only show "添加" button when there are devices
              if (hasDevices)
                GestureDetector(
                  onTap: onQRTap,
                  child: Text(
                    '+ 添加',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: deviceState.devices.isEmpty
                ? _buildEmptyDevices()
                : ListView.separated(
                    itemCount: deviceState.devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _buildDeviceItem(context, deviceState.devices[index], ref);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDevices() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 32,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无设备',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, Device device, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accentLight, const Color(0xFFD4E6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getDeviceIcon(device.browser),
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (device.isActive) ...[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      device.isActive ? '在线' : '离线',
                      style: TextStyle(
                        fontSize: 11,
                        color: device.isActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          GestureDetector(
            onTap: () => _showRemoveDeviceDialog(context, device, ref),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoveDeviceDialog(BuildContext context, Device device, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('移除设备'),
        content: Text('确定要移除 "${device.name}" 吗？该设备将无法继续访问。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '移除',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(deviceProvider.notifier).revokeDevice(device.id);
    }
  }

  IconData _getDeviceIcon(String browser) {
    final lowerBrowser = browser.toLowerCase();
    if (lowerBrowser.contains('chrome')) return Icons.language;
    if (lowerBrowser.contains('safari')) return Icons.phone_iphone;
    if (lowerBrowser.contains('firefox')) return Icons.local_fire_department;
    if (lowerBrowser.contains('edge')) return Icons.web;
    return Icons.devices;
  }

  Widget _buildServerControls(BuildContext context, ServerState serverState, TunnelState tunnelState) {
    final bool isRunning = serverState.isRunning;
    final bool isLoading = serverState.isStarting || tunnelState.isConnecting;

    String label;
    if (isLoading) {
      label = serverState.isStarting ? '启动中...' : '连接中...';
    } else if (isRunning) {
      label = '停止服务';
    } else {
      label = '一键启动';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: _buildSmartButton(
        label: label,
        icon: isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
        onPressed: isLoading ? null : onToggleService,
        isPrimary: !isRunning && !isLoading,
        isDanger: isRunning && !isLoading,
        isLoading: isLoading,
      ),
    );
  }

  Widget _buildSmartButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isPrimary = false,
    bool isDanger = false,
    bool isLoading = false,
  }) {
    final bool isDisabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isPrimary ? AppColors.primaryGradient : null,
            color: isPrimary
                ? null
                : isDisabled
                    ? AppColors.bgPrimary.withOpacity(0.5)
                    : isDanger
                        ? Colors.transparent
                        : AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(10),
            border: isDanger && !isDisabled
                ? Border.all(color: AppColors.danger.withOpacity(0.5), width: 1.5)
                : isPrimary
                    ? null
                    : Border.all(color: AppColors.border),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.gradientStart.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary
                      ? Colors.white
                      : isDisabled
                          ? AppColors.textSecondary.withOpacity(0.5)
                          : isDanger
                              ? AppColors.danger
                              : AppColors.textPrimary,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? Colors.white
                      : isDisabled
                          ? AppColors.textSecondary.withOpacity(0.5)
                          : isDanger
                              ? AppColors.danger
                              : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
