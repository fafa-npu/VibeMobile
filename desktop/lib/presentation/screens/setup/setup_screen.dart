import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/services/setup_service.dart';
import '../../../core/logging/app_logger.dart';

/// Setup screen state
class SetupState {
  final SetupStatus? status;
  final bool isChecking;
  final bool isInstalling;
  final String? currentStep;
  final String? error;
  final bool setupComplete;

  const SetupState({
    this.status,
    this.isChecking = false,
    this.isInstalling = false,
    this.currentStep,
    this.error,
    this.setupComplete = false,
  });

  SetupState copyWith({
    SetupStatus? status,
    bool? isChecking,
    bool? isInstalling,
    String? currentStep,
    String? error,
    bool? setupComplete,
    bool clearError = false,
    bool clearCurrentStep = false,
  }) {
    return SetupState(
      status: status ?? this.status,
      isChecking: isChecking ?? this.isChecking,
      isInstalling: isInstalling ?? this.isInstalling,
      currentStep: clearCurrentStep ? null : (currentStep ?? this.currentStep),
      error: clearError ? null : (error ?? this.error),
      setupComplete: setupComplete ?? this.setupComplete,
    );
  }
}

/// Setup notifier
class SetupNotifier extends StateNotifier<SetupState> {
  final SetupService _service = SetupService();

  SetupNotifier() : super(const SetupState());

  /// Check environment and dependencies
  Future<void> checkEnvironment() async {
    state = state.copyWith(isChecking: true, clearError: true);

    try {
      final status = await _service.checkEnvironment();
      state = state.copyWith(
        status: status,
        isChecking: false,
        setupComplete: status.isReady,
      );
    } catch (e, stack) {
      AppLogger.error('SetupNotifier: Failed to check environment', e, stack);
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
      );
    }
  }

  /// Run automatic setup
  Future<void> runSetup() async {
    state = state.copyWith(isInstalling: true, clearError: true);

    try {
      final result = await _service.runFullSetup(
        onProgress: (step) {
          state = state.copyWith(currentStep: step);
        },
      );

      if (result.success) {
        await _service.markSetupCompleted();
        state = state.copyWith(
          isInstalling: false,
          setupComplete: true,
          clearCurrentStep: true,
        );
      } else {
        state = state.copyWith(
          isInstalling: false,
          error: result.error,
          clearCurrentStep: true,
        );
        // Recheck environment after failure
        await checkEnvironment();
      }
    } catch (e, stack) {
      AppLogger.error('SetupNotifier: Setup failed', e, stack);
      state = state.copyWith(
        isInstalling: false,
        error: e.toString(),
        clearCurrentStep: true,
      );
    }
  }

  /// Install a single dependency
  Future<void> installDependency(String name) async {
    state = state.copyWith(isInstalling: true, currentStep: 'Installing $name...');

    try {
      SetupResult result;

      switch (name) {
        case 'homebrew':
          result = await _service.installHomebrew();
          break;
        case 'tmux':
        case 'node':
        case 'gh':
        case 'gh-copilot':
        case 'devtunnel':
          result = await _service.installDependencies(
            dependencies: [name],
            onProgress: (step) => state = state.copyWith(currentStep: step),
          );
          break;
        default:
          result = SetupResult.fail('Unknown dependency: $name');
      }

      if (!result.success) {
        state = state.copyWith(
          isInstalling: false,
          error: result.error,
          clearCurrentStep: true,
        );
      } else {
        state = state.copyWith(
          isInstalling: false,
          clearCurrentStep: true,
        );
      }

      // Recheck environment
      await checkEnvironment();
    } catch (e, stack) {
      AppLogger.error('SetupNotifier: Failed to install $name', e, stack);
      state = state.copyWith(
        isInstalling: false,
        error: e.toString(),
        clearCurrentStep: true,
      );
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Setup provider
final setupProvider = StateNotifierProvider<SetupNotifier, SetupState>((ref) {
  return SetupNotifier();
});

/// Setup screen - first-run configuration wizard
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  @override
  void initState() {
    super.initState();
    // Check environment on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(setupProvider.notifier).checkEnvironment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and title
                Icon(
                  Icons.rocket_launch,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to VibeMobile',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s set up your environment',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Dependency list
                if (state.isChecking)
                  const Center(child: CircularProgressIndicator())
                else if (state.status != null)
                  _buildDependencyList(state.status!)
                else if (state.error != null)
                  _buildErrorCard(state.error!),

                const SizedBox(height: 32),

                // Progress indicator
                if (state.isInstalling && state.currentStep != null) ...[
                  LinearProgressIndicator(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.currentStep!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],

                // Action buttons
                if (!state.isChecking && state.status != null)
                  _buildActionButtons(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDependencyList(SetupStatus status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final dep in status.allDependencies)
              _buildDependencyItem(dep),
          ],
        ),
      ),
    );
  }

  Widget _buildDependencyItem(DependencyStatus dep) {
    final isInstalled = dep.isInstalled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isInstalled ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isInstalled ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dep.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (dep.version != null)
                  Text(
                    'v${dep.version}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  )
                else if (!isInstalled)
                  Text(
                    'Not installed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          if (!isInstalled)
            TextButton(
              onPressed: ref.watch(setupProvider).isInstalling
                  ? null
                  : () => ref.read(setupProvider.notifier).installDependency(dep.name),
              child: const Text('Install'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(setupProvider.notifier).clearError(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(SetupState state) {
    final status = state.status!;

    if (status.isReady || state.setupComplete) {
      return FilledButton.icon(
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Get Started'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: state.isInstalling
              ? null
              : () => ref.read(setupProvider.notifier).runSetup(),
          icon: state.isInstalling
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high),
          label: Text(state.isInstalling ? 'Installing...' : 'Install All'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.isInstalling ? null : () => context.go('/'),
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}
