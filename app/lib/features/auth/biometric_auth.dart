import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// 系统生物识别（指纹/人脸）封装。仅 Android/iOS 可用，桌面端一律 false。
class BiometricAuth {
  BiometricAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static bool get platformSupported => Platform.isAndroid || Platform.isIOS;

  /// 设备具备生物识别能力（有指纹/人脸硬件并已录入）。
  Future<bool> canUnlock() async {
    if (!platformSupported) return false;
    try {
      final hasHardware = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return hasHardware || deviceSupported;
    } on Object {
      return false;
    }
  }

  /// 弹出系统生物识别验证。
  Future<bool> authenticate() async {
    if (!platformSupported) return false;
    try {
      return await _auth.authenticate(
        localizedReason: '验证指纹以解锁漫读',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>((ref) => BiometricAuth());
