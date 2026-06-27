import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dll_path.dart';
final class BadEngine {
  late final DynamicLibrary _lib;
  late final BadPageNew _pageNew;
  late final BadPageFetch _pageFetch;
  late final BadFree _free;
  late final BadSetVersion _setVersion;
  late final BadSetMode _setMode;
  bool _loaded = false;
  static BadEngine? _instance;

  BadEngine._();

  static BadEngine get instance {
    _instance ??= BadEngine._();
    return _instance!;
  }


  void load() {
    if (_loaded) return;
    final dllPath = DllFinder.find();

    _lib = DynamicLibrary.open(dllPath);

    _pageNew = _lib
        .lookupFunction<BadPageNewNative, BadPageNew>('bad_page_new');
    _pageFetch = _lib
        .lookupFunction<BadPageFetchNative, BadPageFetch>('bad_page_fetch');
    _free = _lib.lookupFunction<BadFreeNative, BadFree>('bad_free');
    _setVersion = _lib
        .lookupFunction<BadSetVersionNative, BadSetVersion>(
            'bad_set_chrome_version');
    _setMode = _lib
        .lookupFunction<BadSetModeNative, BadSetMode>('bad_set_mode');
    _loaded = true;
  }

  int createPage() {
    load();
    return _pageNew();
  }

  void setChromeVersion(String version) {
    load();
    final ptr = version.toNativeUtf8(allocator: malloc);
    _setVersion(ptr.cast<Uint8>());
    malloc.free(ptr);
  }
  
  void setMode(int mode) {
    load();
    _setMode(mode);
  }
  
  String? fetchPage(int handle, String url) {
    load();
    final urlPtr = url.toNativeUtf8(allocator: malloc);
    final result = _pageFetch(handle, urlPtr.cast<Uint8>());
    malloc.free(urlPtr);

    if (result == nullptr) return null;
    final bytes = result.cast<Uint8>();
    var len = 0;
    while (bytes[len] != 0) len++;
    final slice = bytes.asTypedList(len);
    final body = utf8.decode(slice, allowMalformed: true);
    _free(result);
    return body;
  }
}

typedef BadPageNewNative = Int32 Function();
typedef BadPageNew = int Function();

typedef BadPageFetchNative = Pointer<Uint8> Function(
    Uint32, Pointer<Uint8>);
typedef BadPageFetch = Pointer<Uint8> Function(int, Pointer<Uint8>);

typedef BadFreeNative = Void Function(Pointer<Uint8>);
typedef BadFree = void Function(Pointer<Uint8>);

typedef BadSetVersionNative = Void Function(Pointer<Uint8>);
typedef BadSetVersion = void Function(Pointer<Uint8>);

typedef BadSetModeNative = Void Function(Int32);
typedef BadSetMode = void Function(int);