// 匿名/登录探测 app gRPC `PlayViewUnite`，验证「大会员画质试看」分支的
// 请求链路与回复解析。默认走 HTTP/2（package:http2，与 dio_http2_adapter 一致）。
//
// 用法:
//   dart run tool/grpc_probe.dart [bvid] [cid] [qn] [accessKey] [--dm] [--h1] [--host=host]
//   dart run tool/grpc_probe.dart --login        # 扫码登录后自动跑试看授予对照实验
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:PiliPlus/grpc/bilibili/app/playerunite/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart' as dm;
import 'package:PiliPlus/grpc/bilibili/metadata/device.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/fawkes.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/locale.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/network.pb.dart' as network;
import 'package:PiliPlus/grpc/bilibili/metadata.pb.dart';
import 'package:PiliPlus/grpc/bilibili/playershared.pb.dart' as playershared;
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:http2/transport.dart';
import 'package:protobuf/protobuf.dart';
import 'package:qr/qr.dart';

const _defaultHost = 'app.bilibili.com';
const _device = 'android';
const _channel = 'master';
const _appKeyHd = 'dfca71928277209b';
const _appSecHd = 'b5475a8825547a4fc26c7d518eaaa02e';

class ClientProfile {
  final String name, mobiApp, model, ua, versionName;
  final int build, appId;
  const ClientProfile(this.name, this.mobiApp, this.build, this.appId,
      this.model, this.ua, this.versionName);
}

// PiliPlus 使用的 HD 客户端身份
const hdProfile = ClientProfile(
  'android_hd',
  'android_hd',
  2001100,
  5,
  'android_hd',
  'Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android '
      'model/android_hd mobi_app/android_hd build/2001100 channel/master '
      'innerVer/2001100 osVer/15 network/2',
  '2.0.1',
);

// 官方手机客户端身份
const phoneProfile = ClientProfile(
  'android',
  'android',
  8430300,
  1,
  'M2012K11AC',
  'Mozilla/5.0 BiliDroid/8.43.0 (bbcallen@gmail.com) os/android '
      'model/M2012K11AC mobi_app/android build/8430300 channel/master '
      'innerVer/8430300 osVer/15 network/2',
  '8.43.0',
);

Future<void> main(List<String> args) async {
  final isDm = args.contains('--dm');
  final isLogin = args.contains('--login');
  final useH1 = args.contains('--h1');
  final host = args
      .where((a) => a.startsWith('--host='))
      .map((a) => a.substring('--host='.length))
      .firstOrNull;
  final grpcHost = (host == null || host.isEmpty) ? _defaultHost : host;
  final positional = args.skipWhile((a) => a.startsWith('--')).toList();
  final bvid = isDm || isLogin || positional.isEmpty
      ? 'BV1GJ411x7h7'
      : positional[0];
  final qn = positional.length > 2 ? int.parse(positional[2]) : 127;
  final accessKey = positional.length > 3 && positional[3].isNotEmpty
      ? positional[3]
      : null;

  final view = await _getJson(
    Uri.parse('https://api.bilibili.com/x/web-interface/view?bvid=$bvid'),
  );
  if (view['code'] != 0) {
    stderr.writeln('view api failed: $view');
    exitCode = 1;
    return;
  }
  final aid = view['data']['aid'] as int;
  final cid = positional.length > 1 && !isDm
      ? int.parse(positional[1])
      : view['data']['cid'] as int;
  stdout
    ..writeln('视频: ${view['data']['title']}')
    ..writeln(
      'host=$grpcHost ${useH1 ? 'HTTP/1.1' : 'HTTP/2'} '
      'aid=$aid cid=$cid qn=$qn '
      '${accessKey == null ? '(匿名)' : '(access_key)'}',
    );

  if (isLogin) {
    final key = await _tvLogin();
    if (key == null) {
      exitCode = 1;
      return;
    }
    await _trialMatrix(
      grpcHost,
      useH1,
      aid: aid,
      cid: cid,
      bvid: bvid,
      accessKey: key,
    );
    return;
  }

  if (args.contains('--url')) {
    final key = accessKey;
    if (key == null) {
      stderr.writeln('--url 需要 accessKey 参数');
      exitCode = 1;
      return;
    }
    await _urlTest(grpcHost, aid: aid, cid: cid, bvid: bvid, accessKey: key, qn: qn);
    return;
  }

  final (path, message) = isDm
      ? (
          '/bilibili.community.service.dm.v1.DM/DmSegMobile',
          dm.DmSegMobileReq(oid: Int64(cid), segmentIndex: Int64(1), type: 1),
        )
      : (
          '/bilibili.app.playerunite.v1.Player/PlayViewUnite',
          PlayViewUniteReq(
            vod: playershared.VideoVod(
              aid: Int64(aid),
              cid: Int64(cid),
              qn: Int64(qn),
              fnval: 4048,
              fourk: true,
              forceHost: 2,
              isNeedTrial: true,
            ),
            spmid: 'main.ugc-video-detail.0.0.pv',
            fromSpmid: 'main.ugc-video-detail.0.0.videomenu',
            bvid: bvid,
          ),
        );

  final result = useH1
      ? await _sendGrpcH1(grpcHost, path, message, accessKey: accessKey)
      : await _sendGrpcH2(grpcHost, path, message, accessKey: accessKey);
  if (result == null) {
    exitCode = 1;
    return;
  }
  final (grpcStatus, grpcMsg, bytes) = result;
  stdout.writeln('grpc-status=$grpcStatus msg=$grpcMsg');
  if (grpcStatus != '0') {
    exitCode = 1;
    return;
  }

  if (isDm) {
    final reply = dm.DmSegMobileReply.fromBuffer(bytes);
    stdout.writeln('OK: danmaku elems=${reply.elems.length}');
    return;
  }

  _printPlayReply(bytes);
}

void _printPlayReply(Uint8List bytes) {
  final reply = PlayViewUniteReply.fromBuffer(bytes);
  if (!reply.hasVodInfo()) {
    stdout.writeln('reply has no vodInfo');
    exitCode = 1;
    return;
  }
  final videoInfo = reply.vodInfo;
  stdout
    ..writeln('quality=${videoInfo.quality} format=${videoInfo.format}')
    ..writeln('timelength=${videoInfo.timelength} ms')
    ..writeln('--- streams ---');
  for (final stream in videoInfo.streamList) {
    final info = stream.streamInfo;
    final content = stream.hasDashVideo()
        ? 'dash'
        : stream.hasMultiDashVideo()
        ? 'multi-dash(${stream.multiDashVideo.dashVideos.length})'
        : stream.hasSegmentVideo()
        ? 'segment(${stream.segmentVideo.segment.length})'
        : 'none';
    stdout.writeln(
      'qn=${info.quality} ${info.newDescription} intact=${info.intact} '
      'needVip=${info.needVip} vipFree=${info.vipFree} content=$content',
    );
  }
  stdout.writeln('dashAudio ids: ${videoInfo.dashAudio.map((a) => a.id)}');
}

/// 拉取试看流的真实 URL 并测试不同请求头下的可访问性
Future<void> _urlTest(
  String grpcHost, {
  required int aid,
  required int cid,
  required String bvid,
  required String accessKey,
  required int qn,
}) async {
  final (path, message) = (
    '/bilibili.app.playerunite.v1.Player/PlayViewUnite',
    PlayViewUniteReq(
      vod: playershared.VideoVod(
        aid: Int64(aid),
        cid: Int64(cid),
        qn: Int64(qn),
        fnval: 4048,
        fourk: true,
        forceHost: 2,
        isNeedTrial: true,
      ),
      spmid: 'main.ugc-video-detail.0.0.pv',
      fromSpmid: 'main.ugc-video-detail.0.0.videomenu',
      bvid: bvid,
    ),
  );
  final r = await _sendGrpcH2(
    grpcHost,
    path,
    message,
    accessKey: accessKey,
    profile: phoneProfile,
  );
  if (r == null || r.$1 != '0') {
    stdout.writeln('grpc failed');
    return;
  }
  final reply = PlayViewUniteReply.fromBuffer(r.$3);
  if (!reply.hasVodInfo()) {
    stdout.writeln('no vodInfo');
    return;
  }
  for (final stream in reply.vodInfo.streamList) {
    if (stream.streamInfo.quality <= 80) continue;
    final String url;
    if (stream.hasDashVideo()) {
      url = stream.dashVideo.baseUrl;
    } else if (stream.hasMultiDashVideo() &&
        stream.multiDashVideo.dashVideos.isNotEmpty) {
      url = stream.multiDashVideo.dashVideos.first.baseUrl;
    } else {
      stdout.writeln('qn=${stream.streamInfo.quality}: no content');
      continue;
    }
    stdout
      ..writeln('qn=${stream.streamInfo.quality} url=$url')
      ..writeln('backup: ${stream.hasDashVideo() ? stream.dashVideo.backupUrl : '<multi>'}');
    // 定位 403 触发条件: UA/Referer 组合矩阵 + mpv 仿真(开放 Range)
    const pcUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';
    final trialUrl = () {
      final urls = [
        if (stream.hasDashVideo()) ...[stream.dashVideo.baseUrl, ...stream.dashVideo.backupUrl],
      ];
      return urls.firstWhere(
        (u) => Uri.parse(u).host.endsWith('bilivideo.com'),
        orElse: () => urls.isNotEmpty ? urls.first : url,
      );
    }();
    stdout.writeln('trial mirror: $trialUrl');
    for (final (label, hdrs) in [
      ('app-noref', {'user-agent': phoneProfile.ua}),
      ('app-ref', {'user-agent': phoneProfile.ua, 'referer': 'https://www.bilibili.com/'}),
      ('pc-noref', {'user-agent': pcUa}),
      ('pc-ref', {'user-agent': pcUa, 'referer': 'https://www.bilibili.com/'}),
      ('mpv-sim', {
        'user-agent': phoneProfile.ua,
        'accept': '*/*',
        'icy-metadata': '1',
      }),
    ]) {
      try {
        final client = HttpClient()..autoUncompress = false;
        final req = await client.getUrl(Uri.parse(trialUrl));
        req.headers.set('range', 'bytes=0-');
        hdrs.forEach(req.headers.set);
        final res = await req.close();
        await res.drain();
        stdout.writeln('  [$label] status=${res.statusCode}');
        client.close(force: true);
      } catch (e) {
        stdout.writeln('  [$label] error: $e');
      }
    }
  }
}

/// TV 扫码登录(与 PiliPlus 登录同流程), 返回 access_key
Future<String?> _tvLogin() async {
  final buvid = _genBuvid();
  final auth = await _postForm(
    Uri.parse(
      'https://passport.bilibili.com/x/passport-tv-login/qrcode/auth_code',
    ),
    _appSign({'local_id': '0', 'platform': 'android', 'mobi_app': hdProfile.mobiApp}),
    buvid: buvid,
  );
  if (auth['code'] != 0) {
    stderr.writeln('auth_code failed: $auth');
    return null;
  }
  final authCode = auth['data']['auth_code'] as String;
  final url = auth['data']['url'] as String;
  stdout
    ..writeln('== 用手机哔哩哔哩 App 扫描下方二维码并确认登录 ==')
    ..writeln(_renderQr(url))
    ..writeln('(若二维码错位请最大化终端窗口后重跑; 也可把链接发到手机上打开)')
    ..writeln('等待扫码确认中...(最长180秒)');

  final pollParams = {'auth_code': authCode, 'local_id': '0'};
  for (var i = 0; i < 90; i++) {
    await Future.delayed(const Duration(seconds: 2));
    final poll = await _postForm(
      Uri.parse(
        'https://passport.bilibili.com/x/passport-tv-login/qrcode/poll',
      ),
      _appSign(Map.of(pollParams)),
      buvid: buvid,
    );
    final code = poll['code'];
    if (code == 0) {
      final data = poll['data'];
      final key = data['access_token'] as String;
      final mid = data['mid'];
      stdout
        ..writeln('登录成功 mid=$mid')
        ..writeln('access_key: $key');
      return key;
    } else if (code == 86090 || code == 86039) {
      stdout.writeln('已扫码, 等待手机端确认...');
    } else if (code == 86101) {
      // 未扫码, 继续等待
    } else if (code == 86038) {
      stderr.writeln('二维码已失效, 请重跑');
      return null;
    } else {
      // 未知状态码也继续等待
      stdout.writeln('poll: $poll');
    }
  }
  stderr.writeln('二维码超时');
  return null;
}

/// 对照实验: 不同客户端身份 × 不同 qn, 检测试看是否被授予
Future<void> _trialMatrix(
  String grpcHost,
  bool useH1, {
  required int aid,
  required int cid,
  required String bvid,
  required String accessKey,
}) async {
  final variants = [
    (hdProfile, 127),
    (hdProfile, 112),
    (phoneProfile, 127),
    (phoneProfile, 112),
  ];
  for (final (profile, qn) in variants) {
    stdout.writeln('=== ${profile.name} qn=$qn ===');
    final (path, message) = (
      '/bilibili.app.playerunite.v1.Player/PlayViewUnite',
      PlayViewUniteReq(
        vod: playershared.VideoVod(
          aid: Int64(aid),
          cid: Int64(cid),
          qn: Int64(qn),
          fnval: 4048,
          fourk: true,
          forceHost: 2,
          isNeedTrial: true,
        ),
        spmid: 'main.ugc-video-detail.0.0.pv',
        fromSpmid: 'main.ugc-video-detail.0.0.videomenu',
        bvid: bvid,
      ),
    );
    final Uint8List bytes;
    if (useH1) {
      final r = await _sendGrpcH1(
        grpcHost,
        path,
        message,
        accessKey: accessKey,
        profile: profile,
      );
      if (r == null || r.$1 != '0') continue;
      bytes = r.$3;
    } else {
      final r = await _sendGrpcH2(
        grpcHost,
        path,
        message,
        accessKey: accessKey,
        profile: profile,
      );
      if (r == null || r.$1 != '0') continue;
      bytes = r.$3;
    }
    final reply = PlayViewUniteReply.fromBuffer(bytes);
    if (!reply.hasVodInfo()) {
      stdout.writeln('no vodInfo');
      continue;
    }
    var granted = false;
    final ladder = <String>[];
    for (final stream in reply.vodInfo.streamList) {
      final info = stream.streamInfo;
      final hasContent = stream.hasDashVideo() ||
          stream.hasMultiDashVideo() ||
          stream.hasSegmentVideo();
      ladder.add('${info.quality}${hasContent ? '✓' : '✗'}');
      if (hasContent && info.quality > 80) granted = true;
    }
    stdout
      ..writeln('ladder: ${ladder.join(',')}')
      ..writeln(granted ? '>>> TRIAL GRANTED <<< (>80 画质有流)' : '>>> DENIED <<<');
  }
  stdout.writeln('=== 实验结束 ===');
}

Map<String, List<String>> _grpcHeaders(
  String path,
  String host,
  ClientProfile profile,
) {
  final buvid = _genBuvid();
  return {
    'content-type': ['application/grpc'],
    'te': ['trailers'],
    'grpc-encoding': ['gzip'],
    'gzip-accept-encoding': ['gzip,identity'],
    'user-agent': [profile.ua],
    'buvid': [buvid],
    'x-bili-trace-id': [
      '11111111111111111111111111111111:1111111111111111:0:0',
    ],
    'x-bili-device-bin': [
      base64Encode(
        Device(
          appId: profile.appId,
          build: profile.build,
          buvid: buvid,
          mobiApp: profile.mobiApp,
          platform: _device,
          channel: _channel,
          brand: _device,
          model: profile.model,
          osver: '15',
          versionName: profile.versionName,
        ).writeToBuffer(),
      ),
    ],
    'x-bili-network-bin': [
      base64Encode(
        network.Network(type: network.NetworkType.WIFI).writeToBuffer(),
      ),
    ],
    'x-bili-locale-bin': [
      base64Encode(
        Locale(
          cLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
          sLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
          timezone: 'Asia/Shanghai',
        ).writeToBuffer(),
      ),
    ],
    'x-bili-fawkes-req-bin': [
      base64Encode(
        FawkesReq(appkey: profile.mobiApp, env: 'prod', sessionId: _genBuvid())
            .writeToBuffer(),
      ),
    ],
    'x-bili-metadata-bin': [
      base64Encode(
        Metadata(
          mobiApp: profile.mobiApp,
          device: _device,
          build: profile.build,
          channel: _channel,
          buvid: buvid,
          platform: _device,
        ).writeToBuffer(),
      ),
    ],
    ':path': [path],
    ':authority': [host],
  };
}

Future<(String?, String?, Uint8List)?> _sendGrpcH2(
  String host,
  String path,
  GeneratedMessage message, {
  String? accessKey,
  ClientProfile profile = hdProfile,
}) async {
  final payload = message.writeToBuffer();
  final body = Uint8List(5 + payload.length)
    ..buffer.asByteData(1, 4).setInt32(0, payload.length, Endian.big)
    ..setAll(5, payload);

  final headers = _grpcHeaders(path, host, profile);
  if (accessKey != null) {
    headers['authorization'] = ['identify_v1 $accessKey'];
  }

  final socket = await SecureSocket.connect(
    host,
    443,
    supportedProtocols: ['h2'],
  );
  final conn = ClientTransportConnection.viaSocket(socket);
  final stream = conn.makeRequest([
    Header.ascii(':method', 'POST'),
    Header.ascii(':scheme', 'https'),
    for (final e in headers.entries) ...[
      if (e.key.startsWith(':'))
        Header.ascii(e.key, e.value.first)
      else
        for (final v in e.value) Header.ascii(e.key, v),
    ],
  ])..sendData(body, endStream: true);

  final data = BytesBuilder(copy: false);
  String? grpcStatus;
  String? grpcMsg;
  var httpStatus = 0;
  try {
    await for (final msg in stream.incomingMessages) {
      if (msg is HeadersStreamMessage) {
        for (final header in msg.headers) {
          final name = utf8.decode(header.name);
          final value = utf8.decode(header.value);
          switch (name) {
            case ':status':
              httpStatus = int.tryParse(value) ?? 0;
            case 'grpc-status':
              grpcStatus = value;
            case 'grpc-message':
              grpcMsg = Uri.decodeComponent(value);
          }
        }
      } else if (msg is DataStreamMessage) {
        data.add(msg.bytes);
      }
    }
  } finally {
    unawaited(conn.finish());
  }
  if (httpStatus != 200) {
    stdout.writeln('http=$httpStatus');
    return null;
  }
  if (data.isEmpty) {
    return (grpcStatus, grpcMsg, Uint8List(0));
  }
  return (grpcStatus, grpcMsg, _decodeFrame(data.takeBytes()));
}

Future<GrpcReply?> _sendGrpcH1(
  String host,
  String path,
  GeneratedMessage message, {
  String? accessKey,
  ClientProfile profile = hdProfile,
}) async {
  final payload = message.writeToBuffer();
  final body = Uint8List(5 + payload.length)
    ..buffer.asByteData(1, 4).setInt32(0, payload.length, Endian.big)
    ..setAll(5, payload);

  final headers = _grpcHeaders(path, host, profile);
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse('https://$host$path'));
  req.headers.set('content-type', 'application/grpc');
  for (final e in headers.entries) {
    if (e.key.startsWith(':')) continue;
    for (final v in e.value) {
      req.headers.add(e.key, v);
    }
  }
  if (accessKey != null) {
    req.headers.set('authorization', 'identify_v1 $accessKey');
  }
  req.add(body);

  final res = await req.close();
  final Uint8List bytes;
  try {
    bytes = await _readAll(res);
  } on HttpException catch (e) {
    stdout.writeln('HTTP/1.1 解析失败(服务端疑似以 HTTP/2 响应): ${e.message}');
    return null;
  }
  // bilibili 的 gRPC 网关把 grpc-status 放在 headers 而非 trailers
  final grpcStatus = res.headers.value('grpc-status');
  var grpcMsg = res.headers.value('grpc-message');
  if (grpcMsg != null) grpcMsg = Uri.decodeComponent(grpcMsg);
  stdout.writeln('http=${res.statusCode}');
  if (res.statusCode != 200) {
    return null;
  }
  return (grpcStatus, grpcMsg, grpcStatus == '0' ? _decodeFrame(bytes) : bytes);
}

typedef GrpcReply = (String?, String?, Uint8List);

Future<Map<String, dynamic>> _getJson(Uri uri) async {
  final client = HttpClient();
  final req = await client.getUrl(uri)
    ..headers.set(
      'user-agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    )
    ..headers.set('referer', 'https://www.bilibili.com/');
  final res = await req.close();
  return jsonDecode(await res.transform(utf8.decoder).join())
      as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _postForm(
  Uri uri,
  Map<String, String> params, {
  String? buvid,
}) async {
  final client = HttpClient();
  final req = await client.postUrl(uri);
  req.headers
    ..set('content-type', 'application/x-www-form-urlencoded; charset=utf-8')
    ..set('user-agent', hdProfile.ua)
    ..set('env', 'prod')
    ..set('app-key', 'android_hd');
  if (buvid != null) {
    req.headers.set('buvid', buvid);
  }
  req.add(utf8.encode(Uri(queryParameters: params).query.replaceFirst('?', '')));
  final res = await req.close();
  return jsonDecode(await res.transform(utf8.decoder).join())
      as Map<String, dynamic>;
}

/// bili appsign: 参数按 key 排序拼接后 md5(query + appsec), 并写入 appkey/ts/sign
Map<String, String> _appSign(Map<String, String> params) {
  final p = Map.of(params)
    ..['appkey'] = _appKeyHd
    ..['ts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  final query = p.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final raw = query.map((e) => '${e.key}=${e.value}').join('&');
  p['sign'] = md5.convert(utf8.encode(raw + _appSecHd)).toString();
  return p;
}

Uint8List _decodeFrame(Uint8List data) {
  final length = ByteData.sublistView(data, 1, 5).getInt32(0, Endian.big);
  final payload = Uint8List.sublistView(data, 5, 5 + length);
  return data[0] == 1 ? Uint8List.fromList(gzip.decode(payload)) : payload;
}

Future<Uint8List> _readAll(HttpClientResponse res) async {
  final builder = await res.fold(
    BytesBuilder(copy: false),
    (b, chunk) => b..add(chunk),
  );
  return builder.takeBytes();
}

String _genBuvid() {
  final rand = Random();
  return '${List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join()}'
      '${DateTime.now().millisecondsSinceEpoch}infoc';
}

String _renderQr(String data) {
  final image = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L),
  );
  final n = image.moduleCount;
  final buffer = StringBuffer();
  for (var y = -2; y < n + 2; y++) {
    final line = StringBuffer();
    for (var x = -2; x < n + 2; x++) {
      final dark = y >= 0 && y < n && x >= 0 && x < n && image.isDark(y, x);
      line.write(dark ? '██' : '  ');
    }
    buffer.writeln(line.toString().replaceAll(RegExp(r'\s+$'), ''));
  }
  return buffer.toString();
}
