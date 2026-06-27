import 'dart:convert';
import 'dart:math';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import '../engine/dll_path.dart';

typedef _PageNew = int Function();
typedef _PageFetch = Pointer<Uint8> Function(int, Pointer<Uint8>);
typedef _BadFree = void Function(Pointer<Uint8>);

_PageNew _loadPageNew(DynamicLibrary lib) {
  return lib.lookupFunction<Int32 Function(), int Function()>('bad_page_new');
}

_PageFetch _loadPageFetch(DynamicLibrary lib) {
  return lib.lookupFunction<
    Pointer<Uint8> Function(Int32, Pointer<Uint8>),
    Pointer<Uint8> Function(int, Pointer<Uint8>)
  >('bad_page_fetch');
}

_BadFree _loadBadFree(DynamicLibrary lib) {
  return lib.lookupFunction<
    Void Function(Pointer<Uint8>),
    void Function(Pointer<Uint8>)
  >('bad_free');
}

String? _doFetch(_PageFetch pageFetch, _BadFree badFree, int handle, String url) {
  final urlPtr = url.toNativeUtf8(allocator: malloc);
  final result = pageFetch(handle, urlPtr.cast<Uint8>());
  malloc.free(urlPtr);
  if (result == nullptr) return null;

  final bytes = result.cast<Uint8>();
  var len = 0;
  while (bytes[len] != 0) len++;
  final slice = bytes.asTypedList(len);
  final body = utf8.decode(slice, allowMalformed: true);
  badFree(result);
  return body;
}

void workerIsolate(List<Object?> args) {
  final sendPort = args[0] as SendPort;
  final url = args[1] as String;
  final dllPath = args[2] as String;

  String? body;
  String? error;

  try {
    final lib = DynamicLibrary.open(dllPath);
    final pageNew = _loadPageNew(lib);
    final pageFetch = _loadPageFetch(lib);
    final badFree = _loadBadFree(lib);

    final handle = pageNew();
    if (handle == 0xFFFFFFFF) {
      error = 'failed to create page';
    } else {
      body = _doFetch(pageFetch, badFree, handle, url);
      if (body == null) error = 'empty response';
    }
  } catch (e) {
    error = e.toString();
  }

  sendPort.send({'url': url, 'body': body, 'error': error});
}

final class IsolateRunner {
  final int concurrency;
  String? _dllPath;

  IsolateRunner({this.concurrency = 50});

  Stream<Map<String, dynamic>> fetchAll(List<String> urls) async* {
    _dllPath ??= DllFinder.find();
    for (var i = 0; i < urls.length; i += concurrency) {
      final batchEnd = min(i + concurrency, urls.length);
      final batch = urls.sublist(i, batchEnd);
      yield* _runBatch(batch);
    }
  }

  Stream<Map<String, dynamic>> _runBatch(List<String> urls) async* {
    final receivePort = ReceivePort();

    for (final url in urls) {
      Isolate.spawn(workerIsolate, <Object?>[
        receivePort.sendPort,
        url,
        _dllPath,
      ]);
    }

    await for (final msg in receivePort.take(urls.length).cast<Map<String, dynamic>>()) {
      yield msg;
    }

    receivePort.close();
  }
}