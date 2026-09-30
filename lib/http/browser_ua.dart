import 'package:PiliPlus/utils/platform_utils.dart';

abstract final class BrowserUa {
  static String get platform => PlatformUtils.isMobile ? mob : pc;

  static const pc =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';

  static const mob =
      'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36';

  /// 官方手机客户端 UA(试看流拒绝 Web UA+Referer 组合)
  static const app =
      'Mozilla/5.0 BiliDroid/8.43.0 (bbcallen@gmail.com) os/android '
      'model/M2012K11AC mobi_app/android build/8430300 channel/master '
      'innerVer/8430300 osVer/15 network/2';
}
