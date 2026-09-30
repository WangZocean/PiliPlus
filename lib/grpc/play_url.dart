import 'package:PiliPlus/grpc/bilibili/app/playerunite/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/playershared.pb.dart' as playershared;
import 'package:PiliPlus/grpc/grpc_req.dart';
import 'package:PiliPlus/grpc/url.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/grpc_headers.dart';
import 'package:fixnum/fixnum.dart';

/// app gRPC 播放地址（试看通道）
///
/// web playurl 对非会员只下发 ≤1080P 的流；gRPC `PlayViewUnite` 在官方
/// 「大会员画质试看」策略下（`isNeedTrial` + 服务端判定）会把大会员画质的
/// 完整视频流下发给非会员，时长限制本由客户端执行。这里不解析试看信息
/// （qnTrialInfo），即实现完整播放（参考 BiliRoamingX）。
abstract final class PlayUrlGrpc {
  static final _videoCodes = {for (final q in VideoQuality.values) q.code};
  static final _audioCodes = {for (final q in AudioQuality.values) q.code};

  static Future<LoadingState<PlayUrlModel>> playView({
    required int aid,
    required int cid,
    required int qn,
    String? bvid,
  }) async {
    // 画质试看仅对手机客户端身份开放, 请求头需整体换装(实验结论)
    final account = Accounts.get(AccountType.video);
    final res = await GrpcReq.request(
      GrpcUrl.playViewUnite,
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
      PlayViewUniteReply.fromBuffer,
      headers: GrpcHeaders.phoneHeaders(account.accessKey),
    );
    return switch (res) {
      Success(:final response) =>
        response.hasVodInfo()
            ? _convert(response.vodInfo)
            : const Error('试看通道未返回视频流'),
      _ => Error(res.toString()),
    };
  }

  static LoadingState<PlayUrlModel> _convert(playershared.VodInfo vodInfo) {
    final video = <Map<String, dynamic>>[];
    final durl = <Map<String, dynamic>>[];
    final supportFormats = <Map<String, dynamic>>[];

    for (final stream in vodInfo.streamList) {
      final info = stream.streamInfo;
      final quality = info.quality;
      if (!_videoCodes.contains(quality)) continue;
      final codecIds = <int>{};
      if (stream.hasDashVideo()) {
        codecIds.add(stream.dashVideo.codecid);
        video.add(_videoItem(quality, stream.dashVideo));
      } else if (stream.hasMultiDashVideo()) {
        for (final item in stream.multiDashVideo.dashVideos) {
          codecIds.add(item.codecid);
          video.add(_videoItem(quality, item));
        }
      } else if (stream.hasSegmentVideo()) {
        for (final seg in stream.segmentVideo.segment) {
          durl.add({
            'order': seg.order,
            'length': seg.length.toInt(),
            'size': seg.size.toInt(),
            'url': seg.url,
            'backup_url': seg.backupUrl,
          });
        }
      }
      supportFormats.add({
        'quality': quality,
        'format': info.format,
        'description': info.description,
        'new_description': info.newDescription,
        'display_desc': info.displayDesc,
        'superscript': info.superscript,
        if (codecIds.isNotEmpty)
          'codecs': [for (final id in codecIds) _videoCodec(id)],
      });
    }

    if (video.isEmpty && durl.isEmpty) {
      // 服务端未授予试看流: 只返回画质梯子(无内容), 附在错误信息里便于诊断
      final ladder = [
        for (final stream in vodInfo.streamList)
          '${stream.streamInfo.quality}'
              '${stream.hasDashVideo() || stream.hasMultiDashVideo() || stream.hasSegmentVideo() ? '✓' : '✗'}',
      ].join(',');
      return Error('未授予[$ladder]');
    }

    final dash = <String, dynamic>{
      'video': video,
      'audio': [
        for (final item in vodInfo.dashAudio)
          if (_audioCodes.contains(item.id)) _audioItem(item),
      ],
    };
    if (vodInfo.hasLossLessItem() &&
        vodInfo.lossLessItem.isLosslessAudio &&
        vodInfo.lossLessItem.hasAudio()) {
      dash['flac'] = {'audio': _audioItem(vodInfo.lossLessItem.audio)};
    }
    if (vodInfo.hasDolby() && vodInfo.dolby.audio.isNotEmpty) {
      dash['dolby'] = {
        'audio': [
          for (final item in vodInfo.dolby.audio) _audioItem(item),
        ],
      };
    }

    return Success(
      PlayUrlModel.fromJson({
        'quality': vodInfo.quality,
        'format': vodInfo.format,
        'timelength': vodInfo.timelength.toInt(),
        'video_codecid': vodInfo.videoCodecid,
        'accept_quality': [for (final f in supportFormats) f['quality']],
        'accept_description': [
          for (final f in supportFormats) f['new_description'],
        ],
        'support_formats': supportFormats,
        if (video.isNotEmpty) 'dash': dash,
        if (durl.isNotEmpty) 'durl': durl,
        if (vodInfo.hasVolume())
          'volume': {
            'measured_i': vodInfo.volume.measuredI,
            'measured_lra': vodInfo.volume.measuredLra,
            'measured_tp': vodInfo.volume.measuredTp,
            'measured_threshold': vodInfo.volume.measuredThreshold,
            'target_offset': vodInfo.volume.targetOffset,
            'target_i': vodInfo.volume.targetI,
            'target_tp': vodInfo.volume.targetTp,
          },
      }),
    );
  }

  static Map<String, dynamic> _videoItem(
    int quality,
    playershared.DashVideo item,
  ) {
    return {
      'id': quality,
      'base_url': item.baseUrl,
      'backup_url': item.backupUrl,
      'bandwidth': item.bandwidth,
      'codecid': item.codecid,
      'size': item.size.toInt(),
      'frame_rate': item.frameRate,
      if (item.width != 0) 'width': item.width,
      if (item.height != 0) 'height': item.height,
      'mime_type': 'video/mp4',
      'codecs': _videoCodec(item.codecid),
      'trial': true,
    };
  }

  static Map<String, dynamic> _audioItem(playershared.DashItem item) {
    return {
      'id': item.id,
      'base_url': item.baseUrl,
      'backup_url': item.backupUrl,
      'bandwidth': item.bandwidth,
      'codecid': item.codecid,
      'size': item.size.toInt(),
      'mime_type': 'audio/mp4',
      'trial': true,
    };
  }

  // DashItem 不带 codecs 字符串，按 codecid 合成 findVideoByQa 依赖的前缀
  static String _videoCodec(int? codecid) => switch (codecid) {
    2 => 'hev1.1.6.L120.90',
    3 => 'av01.0.12M.08',
    _ => 'avc1.640032',
  };
}
