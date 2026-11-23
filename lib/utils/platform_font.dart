import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// arm64 Linux 自带 CJK 字体的判据。
///
/// 背景: Flutter 官方发布的 linux-arm64 桌面引擎**没有链 libfontconfig.so.1**
/// (`readelf -d libflutter_linux_gtk.so | grep fontconfig` 无输出; x64 引擎有),
/// 引擎因此拿不到系统字体链 ⇒ CJK 字形一片空白。
/// 上游: flutter/flutter#90951。同机其它 Flutter 应用症状一致 ⇒ 非本项目引入。
///
/// 绕法: 随包带一份同时覆盖拉丁 + CJK 的 WenQuanYi Micro Hei (Apache-2.0),
/// 在这个平台上把它当主字体(fontFamily)。上游引擎修好后可删除本文件与 pubspec
/// 的 fonts 段。
const String kBundledCjkFamily = 'PiliPlusCjk';

bool get needsBundledCjkFallback {
  if (kIsWeb) return false;
  if (!Platform.isLinux) return false;
  return Abi.current() == Abi.linuxArm64;
}

String? get bundledCjkPrimary =>
    needsBundledCjkFallback ? kBundledCjkFamily : null;
