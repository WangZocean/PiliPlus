import 'dart:convert';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/grpc/bilibili/metadata.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/device.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/fawkes.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/locale.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/network.pb.dart' as network;
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:PiliPlus/utils/utils.dart';

abstract final class GrpcHeaders {
  static const _build = 2001100;
  static const _versionName = '2.0.1';
  static const _biliChannel = 'master';
  static const _mobiApp = 'android_hd';
  static const _device = 'android';

  static String get _buvid => LoginUtils.buvid;
  static String get _traceId => Constants.traceId;
  static String get _sessionId => Utils.generateRandomString(8);

  static final Map<String, String> _base = {
    'grpc-encoding': 'gzip',
    'gzip-accept-encoding': 'gzip,identity',
    'user-agent': Constants.userAgent,
    'x-bili-gaia-vtoken': '',
    'x-bili-aurora-zone': '',
    'x-bili-trace-id': _traceId,
    'buvid': _buvid,
    'bili-http-engine': 'cronet',
    // 'te': 'trailers', // dio not supported
    'x-bili-device-bin': base64Encode(
      Device(
        appId: 5,
        build: _build,
        buvid: _buvid,
        mobiApp: _mobiApp,
        platform: _device,
        channel: _biliChannel,
        brand: _device,
        model: _device,
        osver: '15',
        versionName: _versionName,
      ).writeToBuffer(),
    ),
    'x-bili-network-bin': base64Encode(
      network.Network(type: network.NetworkType.WIFI).writeToBuffer(),
    ),
    'x-bili-locale-bin': base64Encode(
      Locale(
        cLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
        sLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
        timezone: 'Asia/Shanghai',
      ).writeToBuffer(),
    ),
    'x-bili-exps-bin': '',
  };

  static String get fawkes => base64Encode(
    FawkesReq(
      appkey: _mobiApp,
      env: 'prod',
      sessionId: _sessionId,
    ).writeToBuffer(),
  );

  static Map<String, String> newHeaders([String? accessKey, int? mid]) {
    return {
      ..._base,
      if (mid != null) ...{
        'x-bili-mid': '$mid',
        'x-bili-aurora-eid': IdUtils.genAuroraEid(mid),
      },
      if (accessKey != null) 'authorization': 'identify_v1 $accessKey',
      'x-bili-fawkes-req-bin': fawkes,
      'x-bili-metadata-bin': base64Encode(
        Metadata(
          accessKey: accessKey,
          mobiApp: _mobiApp,
          device: _device,
          build: _build,
          channel: _biliChannel,
          buvid: _buvid,
          platform: _device,
        ).writeToBuffer(),
      ),
    };
  }

  // 手机客户端身份(大会员画质试看等能力仅对手机端开放)
  static const _phoneMobiApp = 'android';
  static const _phoneBuild = 8430300;
  static const _phoneVersionName = '8.43.0';
  static const _phoneModel = 'M2012K11AC';
  static const _phoneUa =
      'Mozilla/5.0 BiliDroid/8.43.0 (bbcallen@gmail.com) os/android '
      'model/M2012K11AC mobi_app/android build/8430300 channel/master '
      'innerVer/8430300 osVer/15 network/2';

  /// 与 [newHeaders] 同构, 但以官方手机客户端身份呈现;
  /// 调用方需要自带 authorization(或由拦截器从 grpcHeaders 合并)
  static Map<String, String> phoneHeaders([String? accessKey]) {
    final buvid = LoginUtils.buvid;
    return {
      'user-agent': _phoneUa,
      'buvid': buvid,
      'x-bili-trace-id': Constants.traceId,
      'x-bili-device-bin': base64Encode(
        Device(
          appId: 1,
          build: _phoneBuild,
          buvid: buvid,
          mobiApp: _phoneMobiApp,
          platform: _device,
          channel: _biliChannel,
          brand: _device,
          model: _phoneModel,
          osver: '15',
          versionName: _phoneVersionName,
        ).writeToBuffer(),
      ),
      'x-bili-network-bin': base64Encode(
        network.Network(type: network.NetworkType.WIFI).writeToBuffer(),
      ),
      'x-bili-locale-bin': base64Encode(
        Locale(
          cLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
          sLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
          timezone: 'Asia/Shanghai',
        ).writeToBuffer(),
      ),
      'x-bili-fawkes-req-bin': base64Encode(
        FawkesReq(appkey: _phoneMobiApp, env: 'prod', sessionId: _sessionId)
            .writeToBuffer(),
      ),
      'x-bili-metadata-bin': base64Encode(
        Metadata(
          accessKey: accessKey,
          mobiApp: _phoneMobiApp,
          device: _device,
          build: _phoneBuild,
          channel: _biliChannel,
          buvid: buvid,
          platform: _device,
        ).writeToBuffer(),
      ),
      'x-bili-exps-bin': '',
      if (accessKey != null) 'authorization': 'identify_v1 $accessKey',
    };
  }
}
