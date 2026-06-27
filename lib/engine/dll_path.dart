import 'dart:io';

final class DllFinder {
  static String find() {
    final dir = Directory.current.path;
    for (final p in [
      '$dir/engine.dll',
      '$dir/../engine/build/engine.dll',
    ]) {
      if (File(p).existsSync()) return p;
    }
    throw Exception('engine.dll not found. Build it first.');
  }
}
