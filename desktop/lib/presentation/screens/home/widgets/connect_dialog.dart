import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/device.dart';
import '../../../providers/device_provider.dart';
import '../../../providers/tunnel_provider.dart';

/// Pairing step enum for the connect dialog.
enum PairingStep {
  scanQR,      // Step 1: Scan QR code
  enterCode,   // Step 2: Enter pairing code
  confirmPair, // Step 3: Confirm pairing request
  success,     // Step 4: Pairing success
}

/// A step-by-step connect dialog for device pairing.
class ConnectDialog extends ConsumerStatefulWidget {
  final PairingStep initialStep;

  const ConnectDialog({
    super.key,
    this.initialStep = PairingStep.scanQR,
  });

  @override
  ConsumerState<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends ConsumerState<ConnectDialog>
    with SingleTickerProviderStateMixin {
  late PairingStep _currentStep;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    // Generate pairing code when entering step 2
    if (_currentStep == PairingStep.enterCode) {
      _generatePairingCode();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _generatePairingCode() {
    ref.read(deviceProvider.notifier).generatePairingCode();
  }

  void _goToStep(PairingStep step) {
    setState(() {
      _currentStep = step;
    });
    _animationController.reset();
    _animationController.forward();

    if (step == PairingStep.enterCode) {
      _generatePairingCode();
    }
  }

  Future<void> _approvePairing(String approvalId) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final success = await ref.read(deviceProvider.notifier).approvePairing(approvalId);

    if (success && mounted) {
      _goToStep(PairingStep.success);
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _rejectPairing(String approvalId) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    await ref.read(deviceProvider.notifier).rejectPairing(approvalId);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider);

    // Auto-navigate to confirm step when pairing request arrives
    if (deviceState.pendingRequest != null &&
        _currentStep != PairingStep.confirmPair &&
        _currentStep != PairingStep.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToStep(PairingStep.confirmPair);
      });
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
            boxShadow: AppColors.cardShadowLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),
              // Step indicator
              _buildStepIndicator(),
              // Content - scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildContent(deviceState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.devices_other,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '连接新设备',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getStepTitle(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case PairingStep.scanQR:
        return '步骤 1/4 - 扫描二维码';
      case PairingStep.enterCode:
        return '步骤 2/4 - 输入配对码';
      case PairingStep.confirmPair:
        return '步骤 3/4 - 确认配对';
      case PairingStep.success:
        return '步骤 4/4 - 配对成功';
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildStepDot(PairingStep.scanQR),
          _buildStepLine(PairingStep.scanQR),
          _buildStepDot(PairingStep.enterCode),
          _buildStepLine(PairingStep.enterCode),
          _buildStepDot(PairingStep.confirmPair),
          _buildStepLine(PairingStep.confirmPair),
          _buildStepDot(PairingStep.success),
        ],
      ),
    );
  }

  Widget _buildStepDot(PairingStep step) {
    final isActive = _currentStep.index >= step.index;
    final isCurrent = _currentStep == step;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCurrent ? 28 : 20,
      height: isCurrent ? 28 : 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.gradientStart : AppColors.border,
        border: isCurrent
            ? Border.all(color: AppColors.gradientEnd, width: 3)
            : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.gradientStart.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isActive
            ? Icon(
                step == PairingStep.success && _currentStep == PairingStep.success
                    ? Icons.check
                    : Icons.circle,
                size: isCurrent ? 10 : 8,
                color: Colors.white,
              )
            : null,
      ),
    );
  }

  Widget _buildStepLine(PairingStep step) {
    final isActive = _currentStep.index > step.index;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gradientStart : AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildContent(DeviceListState deviceState) {
    switch (_currentStep) {
      case PairingStep.scanQR:
        return _buildScanQRContent();
      case PairingStep.enterCode:
        return _buildEnterCodeContent(deviceState);
      case PairingStep.confirmPair:
        return _buildConfirmPairContent(deviceState);
      case PairingStep.success:
        return _buildSuccessContent();
    }
  }

  Widget _buildScanQRContent() {
    final tunnelState = ref.watch(tunnelProvider);
    final hasUrl = tunnelState.publicUrl != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: hasUrl
                ? QrImageView(
                    data: tunnelState.publicUrl!,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  )
                : Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '请先启动 Tunnel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '使用手机浏览器扫描二维码，打开控制页面',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // URL display and copy
          if (hasUrl) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tunnelState.publicUrl!,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tunnelState.publicUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('URL 已复制到剪贴板'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, size: 18, color: AppColors.accent),
                    splashRadius: 18,
                    tooltip: '复制链接',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasUrl ? () => _goToStep(PairingStep.enterCode) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gradientStart,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                '下一步：输入配对码',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterCodeContent(DeviceListState deviceState) {
    final pairingCode = deviceState.currentPairingCode;
    final hasCode = pairingCode != null && !pairingCode.isExpired;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Pairing code display
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bgPrimary,
                  AppColors.bgPrimary.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  '配对码',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                if (hasCode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: pairingCode.code.split('').map((char) {
                      return Container(
                        width: 48,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gradientStart,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Container(
                    height: 56,
                    child: Center(
                      child: deviceState.isLoading
                          ? const CircularProgressIndicator()
                          : TextButton.icon(
                              onPressed: _generatePairingCode,
                              icon: const Icon(Icons.refresh),
                              label: const Text('生成配对码'),
                            ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Countdown timer
                if (hasCode) ...[
                  _buildCountdownProgress(pairingCode),
                  const SizedBox(height: 8),
                  Text(
                    '${pairingCode.remainingSeconds} 秒后过期',
                    style: TextStyle(
                      color: pairingCode.remainingSeconds < 30
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '在手机浏览器中输入此配对码以完成连接',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Waiting indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '等待设备连接...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Back button
          TextButton(
            onPressed: () => _goToStep(PairingStep.scanQR),
            child: Text(
              '返回上一步',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownProgress(PairingCode code) {
    final progress = code.remainingSeconds / code.expiresIn;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation<Color>(
          progress < 0.3 ? AppColors.danger : AppColors.gradientStart,
        ),
        minHeight: 6,
      ),
    );
  }

  Widget _buildConfirmPairContent(DeviceListState deviceState) {
    final request = deviceState.pendingRequest;

    if (request == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '等待配对请求...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _goToStep(PairingStep.enterCode),
              child: Text(
                '返回上一步',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Device info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  request.deviceName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${request.browser} · ${request.os}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IP: ${request.ip}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '请确认这是您的设备。批准后该设备将获得访问权限。',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _rejectPairing(request.approvalId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '拒绝',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _approvePairing(request.approvalId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '批准连接',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Success animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.5 + (0.5 * value),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 64,
                      color: AppColors.success,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '设备配对成功！',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '您现在可以通过手机控制桌面端了',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gradientStart,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the connect dialog.
Future<void> showConnectDialog(
  BuildContext context, {
  PairingStep initialStep = PairingStep.scanQR,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConnectDialog(initialStep: initialStep),
  );
}
