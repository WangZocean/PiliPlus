// 手写的最小 proto 子集（非生成文件）。
//
// 仓库未内置 bilibili.app.playerunite.v1 的生成代码，这里按
// stmtc233/bapis-proto 的 extracted_proto/com/bapis/bilibili/app/playerunite/v1/
// {messages,services}.proto 定义，手写 PlayViewUniteReq/PlayViewUniteReply 中
// 本项目用到的字段；未声明字段走 protobuf 未知字段机制，不影响解析。
// 服务: bilibili.app.playerunite.v1.Player/PlayViewUnite
// ignore_for_file: annotate_overrides, constant_identifier_names, non_constant_identifier_names
import 'dart:core' as $core;

import 'package:PiliPlus/grpc/bilibili/playershared.pb.dart';
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PlayViewUniteReq extends $pb.GeneratedMessage {
  factory PlayViewUniteReq({
    VideoVod? vod,
    $core.String? spmid,
    $core.String? fromSpmid,
    $core.String? bvid,
  }) {
    final result = PlayViewUniteReq._();
    if (vod != null) result.vod = vod;
    if (spmid != null) result.spmid = spmid;
    if (fromSpmid != null) result.fromSpmid = fromSpmid;
    if (bvid != null) result.bvid = bvid;
    return result;
  }

  PlayViewUniteReq._();

  factory PlayViewUniteReq.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewUniteReq()..mergeFromBuffer(data, registry);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReq clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReq copyWith(void Function(PlayViewUniteReq) updates) =>
      super.copyWith((message) => updates(message as PlayViewUniteReq))
          as PlayViewUniteReq;

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayViewUniteReq',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.playerunite.v1'),
      createEmptyInstance: PlayViewUniteReq.$_createMessage)
    ..aOM<VideoVod>(1, _omitFieldNames ? '' : 'vod',
        subBuilder: VideoVod.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'spmid')
    ..aOS(3, _omitFieldNames ? '' : 'fromSpmid')
    ..aOS(5, _omitFieldNames ? '' : 'bvid')
    ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayViewUniteReq create() => PlayViewUniteReq._();
  static $pb.GeneratedMessage $_createMessage() => PlayViewUniteReq._();
  @$core.override
  PlayViewUniteReq createEmptyInstance() => PlayViewUniteReq._();

  @$pb.TagNumber(1)
  VideoVod get vod => $_getN(0);
  @$pb.TagNumber(1)
  set vod(VideoVod value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVod() => $_has(0);
  @$pb.TagNumber(1)
  VideoVod ensureVod() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get spmid => $_getSZ(1);
  @$pb.TagNumber(2)
  set spmid($core.String value) => $_setString(1, value);

  @$pb.TagNumber(3)
  $core.String get fromSpmid => $_getSZ(2);
  @$pb.TagNumber(3)
  set fromSpmid($core.String value) => $_setString(2, value);

  @$pb.TagNumber(5)
  $core.String get bvid => $_getSZ(3);
  @$pb.TagNumber(5)
  set bvid($core.String value) => $_setString(3, value);
}

class PlayViewUniteReply extends $pb.GeneratedMessage {
  factory PlayViewUniteReply({VodInfo? vodInfo}) {
    final result = PlayViewUniteReply._();
    if (vodInfo != null) result.vodInfo = vodInfo;
    return result;
  }

  PlayViewUniteReply._();

  factory PlayViewUniteReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayViewUniteReply()..mergeFromBuffer(data, registry);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayViewUniteReply copyWith(void Function(PlayViewUniteReply) updates) =>
      super.copyWith((message) => updates(message as PlayViewUniteReply))
          as PlayViewUniteReply;

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayViewUniteReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.app.playerunite.v1'),
      createEmptyInstance: PlayViewUniteReply.$_createMessage)
    ..aOM<VodInfo>(1, _omitFieldNames ? '' : 'vodInfo',
        subBuilder: VodInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlayViewUniteReply create() => PlayViewUniteReply._();
  static $pb.GeneratedMessage $_createMessage() => PlayViewUniteReply._();
  @$core.override
  PlayViewUniteReply createEmptyInstance() => PlayViewUniteReply._();

  @$pb.TagNumber(1)
  VodInfo get vodInfo => $_getN(0);
  @$pb.TagNumber(1)
  set vodInfo(VodInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVodInfo() => $_has(0);
  @$pb.TagNumber(1)
  VodInfo ensureVodInfo() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
