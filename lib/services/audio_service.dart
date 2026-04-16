import 'dart:io';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  Future<String?> processAudio({
    required String inputPath,
    required double startSeconds,
    required double endSeconds,
    required double speed,
    required String format,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String outputPath = '${tempDir.path}/edited_$timestamp.$format';

    // FFmpeg command construction
    // -i: input
    // -ss: start time
    // -to: end time
    // -filter:a "atempo=speed": audio speed filter (atempo must be between 0.5 and 2.0)
    
    // Note: If we use atempo and seeking, we need to be careful about order.
    // -ss and -to before -i is faster (input seeking).
    
    String atempoFilter = 'atempo=$speed';
    if (speed > 2.0) {
      // Need to chain atempo for speeds > 2.0
      double remaining = speed;
      List<String> filters = [];
      while (remaining > 2.0) {
        filters.add('atempo=2.0');
        remaining /= 2.0;
      }
      filters.add('atempo=$remaining');
      atempoFilter = filters.join(',');
    } else if (speed < 0.5) {
      double remaining = speed;
      List<String> filters = [];
      while (remaining < 0.5) {
        filters.add('atempo=0.5');
        remaining /= 0.5;
      }
      filters.add('atempo=$remaining');
      atempoFilter = filters.join(',');
    }

    // Optimization: If no speed change, we don't need re-encoding for just trimming
    String command;
    if (speed == 1.0) {
       command = '-y -i "$inputPath" -ss $startSeconds -to $endSeconds -c copy "$outputPath"';
    } else {
       command = '-y -i "$inputPath" -ss $startSeconds -to $endSeconds -filter:a "$atempoFilter" "$outputPath"';
    }

    print('Executing FFmpeg command: $command');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      final logs = await session.getAllLogsAsString();
      print('FFmpeg Error: $logs');
      return null;
    }
  }
}
