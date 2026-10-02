import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'auth_controller.dart';
import 'biometric_auth.dart';

/// PIN 门控页：首次设置 PIN / 解锁（移动端可指纹）。
class AuthGatePage extends ConsumerStatefulWidget {
  const AuthGatePage({super.key});

  static const path = '/auth';

  @override
  ConsumerState<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends ConsumerState<AuthGatePage> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _bioSupported = false;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final bio = ref.read(biometricAuthProvider);
    if (!BiometricAuth.platformSupported) return;
    final can = await bio.canUnlock();
    if (mounted) setState(() => _bioSupported = can);
  }

  /// 已进入锁屏且启用过指纹：自动唤起一次系统生物识别。
  Future<void> _tryAutoBiometric() async {
    if (_autoPrompted) return;
    _autoPrompted = true;
    final bio = ref.read(biometricAuthProvider);
    if (!await bio.canUnlock()) return;
    if (!await ref.read(authControllerProvider.notifier).isBiometricEnabled()) {
      return;
    }
    if (await bio.authenticate()) {
      await ref.read(authControllerProvider.notifier).unlockWithBiometric();
    }
  }

  Future<void> _unlockBiometric() async {
    final bio = ref.read(biometricAuthProvider);
    if (!await bio.authenticate()) return; // 用户取消或失败，保持锁屏
    final ok = await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometric();
    if (!ok && mounted) {
      setState(() => _error = '指纹解锁未启用或 PIN 已变更，请用 PIN 解锁');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validPinFormat(String pin) =>
      pin.length >= 4 && pin.length <= 12 && int.tryParse(pin) != null;

  Future<void> _setup() async {
    final pin = _pinController.text;
    if (!_validPinFormat(pin)) {
      setState(() => _error = 'PIN 需为 4–12 位数字');
      return;
    }
    if (pin != _confirmController.text) {
      setState(() => _error = '两次输入不一致');
      return;
    }
    await ref.read(authControllerProvider.notifier).setupPin(pin);
  }

  Future<void> _unlock() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .unlock(_pinController.text);
    if (!ok) setState(() => _error = 'PIN 错误');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('漫读')),
      body: auth.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('初始化失败: $e')),
        data: (state) {
          final isSetup = state.phase == AuthPhase.needsSetup;
          if (!isSetup && _bioSupported && !_autoPrompted) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _tryAutoBiometric(),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isSetup ? '设置应用 PIN' : '输入 PIN 解锁',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isSetup) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '确认 PIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isSetup ? _setup : _unlock,
                  child: Text(isSetup ? '设置并进入' : '解锁'),
                ),
                if (!isSetup && _bioSupported) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _unlockBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('指纹解锁'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
