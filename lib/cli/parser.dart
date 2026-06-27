import 'dart:io';

final class CliArgs {
  final List<String> urls;
  final bool jsonOutput;
  final int mode; // 0=chrome, 1=firefox, 2=curl

  CliArgs._(this.urls, this.jsonOutput, this.mode);

  bool get isEmpty => urls.isEmpty;
  bool get hasSingleUrl => urls.length == 1;
}

CliArgs parseCliArgs(List<String> args) {
  var jsonOutput = false;
  var mode = 0;
  final urls = <String>[];
  var i = 0;

  while (i < args.length) {
    final arg = args[i];
    if (arg == '-j' || arg == '--json') {
      jsonOutput = true;
      i++;
      continue;
    }
    if (arg == '-f' || arg == '--from-file') {
      i++;
      if (i >= args.length) {
        throw Exception('missing file path after $arg');
      }
      final file = File(args[i]);
      if (!file.existsSync()) {
        throw Exception('file not found: ${args[i]}');
      }
      final content = file.readAsStringSync();
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          urls.add(trimmed);
        }
      }
      i++;
      continue;
    }
    if (arg == '-h' || arg == '--help') {
      return CliArgs._([], jsonOutput, mode);
    }
    if (arg == '--firefox') {
      mode = 1;
      i++;
      continue;
    }
    if (arg == '--curl') {
      mode = 2;
      i++;
      continue;
    }
    urls.add(arg);
    i++;
  }

  return CliArgs._(urls, jsonOutput, mode);
}

void printHelp() {
  print('Usage: bf [options] <url> [<url>...]');
  print('');
  print('Options:');
  print('  -j, --json       Output as JSON lines');
  print('  -f, --from-file  Read URLs from a file (one per line)');
  print('  --firefox        Firefox mode (hide Chrome fingerprint)');
  print('  --curl           Curl mode (bare minimum headers)');
  print('  -h, --help       Show this help');
  print('');
  print('Examples:');
  print('  bf https://www.google.com');
  print('  bf --firefox https://www.google.com');
  print('  bf --curl https://www.google.com');
  print('  bf -j url1 url2 url3');
  print('  bf -f links.txt');
}

