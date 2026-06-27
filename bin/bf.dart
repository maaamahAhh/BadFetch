import 'package:badfetch/cli/parser.dart';
import 'package:badfetch/cli/runner_isolate.dart';
import 'package:badfetch/engine/native.dart';
import 'dart:convert';
import 'dart:io';

const _versionFile = 'versions.json';
const _defaultVersion = '131';

Future<void> main(List<String> args) async {
  if (args.length == 1 && args[0] == '--update-versions') {
    await _updateVersions();
    return;
  }

  final parsed = parseCliArgs(args);
  if (parsed.isEmpty) {
    printHelp();
    exit(parsed.jsonOutput ? 0 : 1);
  }

  final engine = BadEngine.instance;
  engine.setMode(parsed.mode);
  if (parsed.mode == 0) engine.setChromeVersion(_loadVersion());

  var hasFailures = false;
  await for (final r in IsolateRunner().fetchAll(parsed.urls)) {
    final url = r['url'] as String;
    final body = r['body'] as String?;
    final error = r['error'] as String?;

    if (body != null) {
      if (parsed.jsonOutput) {
        print(_jsonLine(url, true, body.length.toString()));
      } else {
        print(body);
      }
    } else {
      hasFailures = true;
      if (parsed.jsonOutput) {
        print(_jsonLine(url, false, null, error));
      } else {
        print('ERROR $url: $error');
      }
    }
  }

  if (hasFailures) exit(1);
}

String _jsonLine(String url, bool success, [String? length, String? error]) {
  final e = _escape(url);
  if (success) return '{"url":"$e","success":true,"length":$length}';
  return '{"url":"$e","success":false,"error":"${_escape(error!)}"}';
}

String _loadVersion() {
  try {
    final file = File(_versionFile);
    if (!file.existsSync()) return _defaultVersion;
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (data['chrome'] ?? _defaultVersion).toString();
  } catch (_) {
    return _defaultVersion;
  }
}

Future<void> _updateVersions() async {
  print('Fetching latest Chrome version...');
  try {
    final url = Uri.parse(
        'https://chromiumdash.appspot.com/fetch_releases?platform=Windows&channel=Stable&num=1');
    final client = HttpClient();
    final request = await client.getUrl(url);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    final releases = jsonDecode(body) as List<dynamic>;
    final version = releases[0]['version'] as String;
    final major = version.split('.')[0];

    File(_versionFile).writeAsStringSync(jsonEncode({
      'chrome': major,
      'full_version': version,
      'last_updated': DateTime.now().toIso8601String(),
    }));
    print('Updated to Chrome $major ($version)');
  } catch (e) {
    print('Failed to fetch version: $e');
    print('Using default version $_defaultVersion');
  }
}

String _escape(String s) {
  return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
