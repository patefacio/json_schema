import 'package:dart_dev/dart_dev.dart';
import 'package:glob/glob.dart';

final config = {
  'analyze': AnalyzeTool()
    ..analyzerArgs = ['--fatal-warnings']
    ..include = [
      Glob('bin/'),
      Glob('lib/'),
      Glob('test/'),
      Glob('tool/'),
    ],
  'format': FormatTool()..formatterArgs = ['--line-length=120'],
  'serve': WebdevServeTool()..webdevArgs = ['web:9000'],
  'test': TestTool(),
};
