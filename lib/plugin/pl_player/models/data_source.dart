import 'package:PiliPlus/utils/path_utils.dart';
import 'package:path/path.dart' as path;

sealed class DataSource {
  final String videoSource;
  final String? audioSource;

  DataSource({
    required this.videoSource,
    required this.audioSource,
  });
}

class NetworkSource extends DataSource {
  /// 大会员画质试看流(需要 App UA 且不可走 CDN 改写)
  final bool isTrial;

  NetworkSource({
    required super.videoSource,
    required super.audioSource,
    this.isTrial = false,
  });
}

class FileSource extends DataSource {
  final String dir;
  final bool isMp4;

  FileSource({
    required this.dir,
    required this.isMp4,
    required bool hasDashAudio,
    required String typeTag,
  }) : super(
         videoSource: path.join(
           dir,
           typeTag,
           isMp4 ? PathUtils.videoNameType1 : PathUtils.videoNameType2,
         ),
         audioSource: isMp4 || !hasDashAudio
             ? null
             : path.join(dir, typeTag, PathUtils.audioNameType2),
       );
}
