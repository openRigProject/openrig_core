/// Direct hamlib FFI bindings for rig control.
///
/// Uses dart:ffi to call libhamlib's C API directly, eliminating the need
/// for a rigctld subprocess or TCP connection for local rigs.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'rig_client.dart';

// ---------------------------------------------------------------------------
// hamlib C constants
// ---------------------------------------------------------------------------

// VFO constants
const int _rigVfoCurr = 0x20000000; // RIG_VFO_N(29)
const int _rigVfoA = 0x1; // RIG_VFO_N(0)
const int _rigVfoB = 0x2; // RIG_VFO_N(1)

// PTT constants
const int _rigPttOff = 0;
const int _rigPttOn = 1;

// RIG_LEVEL_STRENGTH
const int _rigLevelStrength = 0x40000000;

// ---------------------------------------------------------------------------
// FFI typedefs
// ---------------------------------------------------------------------------

typedef _RigInitNative = Pointer Function(Int32 model);
typedef _RigInitDart = Pointer Function(int model);

typedef _RigOpenNative = Int32 Function(Pointer rig);
typedef _RigOpenDart = int Function(Pointer rig);

typedef _RigCloseNative = Int32 Function(Pointer rig);
typedef _RigCloseDart = int Function(Pointer rig);

typedef _RigCleanupNative = Int32 Function(Pointer rig);
typedef _RigCleanupDart = int Function(Pointer rig);

typedef _RigSetFreqNative = Int32 Function(Pointer rig, Uint32 vfo, Double freq);
typedef _RigSetFreqDart = int Function(Pointer rig, int vfo, double freq);

typedef _RigGetFreqNative = Int32 Function(
    Pointer rig, Uint32 vfo, Pointer<Double> freq);
typedef _RigGetFreqDart = int Function(
    Pointer rig, int vfo, Pointer<Double> freq);

typedef _RigSetModeNative = Int32 Function(
    Pointer rig, Uint32 vfo, Uint64 mode, Int64 width);
typedef _RigSetModeDart = int Function(
    Pointer rig, int vfo, int mode, int width);

typedef _RigGetModeNative = Int32 Function(
    Pointer rig, Uint32 vfo, Pointer<Uint64> mode, Pointer<Int64> width);
typedef _RigGetModeDart = int Function(
    Pointer rig, int vfo, Pointer<Uint64> mode, Pointer<Int64> width);

typedef _RigSetPttNative = Int32 Function(Pointer rig, Uint32 vfo, Int32 ptt);
typedef _RigSetPttDart = int Function(Pointer rig, int vfo, int ptt);

typedef _RigGetPttNative = Int32 Function(
    Pointer rig, Uint32 vfo, Pointer<Int32> ptt);
typedef _RigGetPttDart = int Function(
    Pointer rig, int vfo, Pointer<Int32> ptt);

typedef _RigSetVfoNative = Int32 Function(Pointer rig, Uint32 vfo);
typedef _RigSetVfoDart = int Function(Pointer rig, int vfo);

typedef _RigGetVfoNative = Int32 Function(Pointer rig, Pointer<Uint32> vfo);
typedef _RigGetVfoDart = int Function(Pointer rig, Pointer<Uint32> vfo);

typedef _RigSetSplitVfoNative = Int32 Function(
    Pointer rig, Uint32 rx, Int32 split, Uint32 tx);
typedef _RigSetSplitVfoDart = int Function(
    Pointer rig, int rx, int split, int tx);

typedef _RigGetSplitVfoNative = Int32 Function(
    Pointer rig, Uint32 rx, Pointer<Int32> split, Pointer<Uint32> tx);
typedef _RigGetSplitVfoDart = int Function(
    Pointer rig, int rx, Pointer<Int32> split, Pointer<Uint32> tx);

typedef _RigGetInfoNative = Pointer<Utf8> Function(Pointer rig);
typedef _RigGetInfoDart = Pointer<Utf8> Function(Pointer rig);

typedef _RigGetLevelNative = Int32 Function(
    Pointer rig, Uint32 vfo, Uint64 level, Pointer<Int32> val);
typedef _RigGetLevelDart = int Function(
    Pointer rig, int vfo, int level, Pointer<Int32> val);

typedef _RigSetConfNative = Int32 Function(
    Pointer rig, Int64 token, Pointer<Utf8> val);
typedef _RigSetConfDart = int Function(
    Pointer rig, int token, Pointer<Utf8> val);

typedef _RigTokenLookupNative = Int64 Function(
    Pointer rig, Pointer<Utf8> name);
typedef _RigTokenLookupDart = int Function(Pointer rig, Pointer<Utf8> name);

typedef _RigStrrmodeNative = Pointer<Utf8> Function(Uint64 mode);
typedef _RigStrrmodeDart = Pointer<Utf8> Function(int mode);

typedef _RigParseModeNative = Uint64 Function(Pointer<Utf8> s);
typedef _RigParseModeDart = int Function(Pointer<Utf8> s);

// ---------------------------------------------------------------------------
// Hamlib FFI bindings
// ---------------------------------------------------------------------------

/// Cached bindings to libhamlib.
class _HamlibBindings {
  final DynamicLibrary lib;

  late final _RigInitDart rigInit;
  late final _RigOpenDart rigOpen;
  late final _RigCloseDart rigClose;
  late final _RigCleanupDart rigCleanup;
  late final _RigSetFreqDart rigSetFreq;
  late final _RigGetFreqDart rigGetFreq;
  late final _RigSetModeDart rigSetMode;
  late final _RigGetModeDart rigGetMode;
  late final _RigSetPttDart rigSetPtt;
  late final _RigGetPttDart rigGetPtt;
  late final _RigSetVfoDart rigSetVfo;
  late final _RigGetVfoDart rigGetVfo;
  late final _RigSetSplitVfoDart rigSetSplitVfo;
  late final _RigGetSplitVfoDart rigGetSplitVfo;
  late final _RigGetInfoDart rigGetInfo;
  late final _RigGetLevelDart rigGetLevel;
  late final _RigSetConfDart rigSetConf;
  late final _RigTokenLookupDart rigTokenLookup;
  late final _RigStrrmodeDart rigStrrmode;
  late final _RigParseModeDart rigParseMode;

  _HamlibBindings(this.lib) {
    rigInit = lib.lookupFunction<_RigInitNative, _RigInitDart>('rig_init');
    rigOpen = lib.lookupFunction<_RigOpenNative, _RigOpenDart>('rig_open');
    rigClose = lib.lookupFunction<_RigCloseNative, _RigCloseDart>('rig_close');
    rigCleanup =
        lib.lookupFunction<_RigCleanupNative, _RigCleanupDart>('rig_cleanup');
    rigSetFreq =
        lib.lookupFunction<_RigSetFreqNative, _RigSetFreqDart>('rig_set_freq');
    rigGetFreq =
        lib.lookupFunction<_RigGetFreqNative, _RigGetFreqDart>('rig_get_freq');
    rigSetMode =
        lib.lookupFunction<_RigSetModeNative, _RigSetModeDart>('rig_set_mode');
    rigGetMode =
        lib.lookupFunction<_RigGetModeNative, _RigGetModeDart>('rig_get_mode');
    rigSetPtt =
        lib.lookupFunction<_RigSetPttNative, _RigSetPttDart>('rig_set_ptt');
    rigGetPtt =
        lib.lookupFunction<_RigGetPttNative, _RigGetPttDart>('rig_get_ptt');
    rigSetVfo =
        lib.lookupFunction<_RigSetVfoNative, _RigSetVfoDart>('rig_set_vfo');
    rigGetVfo =
        lib.lookupFunction<_RigGetVfoNative, _RigGetVfoDart>('rig_get_vfo');
    rigSetSplitVfo = lib.lookupFunction<_RigSetSplitVfoNative,
        _RigSetSplitVfoDart>('rig_set_split_vfo');
    rigGetSplitVfo = lib.lookupFunction<_RigGetSplitVfoNative,
        _RigGetSplitVfoDart>('rig_get_split_vfo');
    rigGetInfo =
        lib.lookupFunction<_RigGetInfoNative, _RigGetInfoDart>('rig_get_info');
    rigGetLevel = lib
        .lookupFunction<_RigGetLevelNative, _RigGetLevelDart>('rig_get_level');
    rigSetConf =
        lib.lookupFunction<_RigSetConfNative, _RigSetConfDart>('rig_set_conf');
    rigTokenLookup = lib.lookupFunction<_RigTokenLookupNative,
        _RigTokenLookupDart>('rig_token_lookup');
    rigStrrmode = lib
        .lookupFunction<_RigStrrmodeNative, _RigStrrmodeDart>('rig_strrmode');
    rigParseMode = lib
        .lookupFunction<_RigParseModeNative, _RigParseModeDart>('rig_parse_mode');
  }
}

/// Error thrown when a hamlib function returns a non-zero code.
class HamlibError implements Exception {
  final int code;
  final String function;
  HamlibError(this.code, this.function);

  @override
  String toString() => 'HamlibError: $function returned $code';
}

/// Resolve the platform-specific path to libhamlib.
String _resolveLibraryPath() {
  if (Platform.isMacOS) {
    // Try Homebrew ARM64, then Intel, then system.
    const candidates = [
      '/opt/homebrew/lib/libhamlib.dylib',
      '/usr/local/lib/libhamlib.dylib',
      'libhamlib.dylib',
    ];
    for (final path in candidates) {
      if (path == candidates.last || File(path).existsSync()) return path;
    }
  }
  if (Platform.isLinux) {
    return 'libhamlib.so';
  }
  throw UnsupportedError(
      'HamlibFfiClient is not supported on ${Platform.operatingSystem}');
}

/// Singleton bindings cache.
_HamlibBindings? _cachedBindings;

_HamlibBindings _getBindings() {
  if (_cachedBindings != null) return _cachedBindings!;
  final path = _resolveLibraryPath();
  final lib = DynamicLibrary.open(path);
  _cachedBindings = _HamlibBindings(lib);
  return _cachedBindings!;
}

// ---------------------------------------------------------------------------
// VFO name <-> int helpers
// ---------------------------------------------------------------------------

const _vfoMap = <String, int>{
  'VFOA': _rigVfoA,
  'VFOB': _rigVfoB,
  'currVFO': _rigVfoCurr,
};

const _vfoReverseMap = <int, String>{
  _rigVfoA: 'VFOA',
  _rigVfoB: 'VFOB',
  _rigVfoCurr: 'currVFO',
};

int _parseVfo(String name) => _vfoMap[name] ?? _rigVfoCurr;
String _vfoName(int vfo) => _vfoReverseMap[vfo] ?? 'currVFO';

// ---------------------------------------------------------------------------
// HamlibFfiClient
// ---------------------------------------------------------------------------

/// Direct hamlib rig control via FFI.
///
/// Provides the same logical API as [RigctldClient] but calls libhamlib
/// C functions directly instead of going through TCP/rigctld.
class HamlibFfiClient implements RigClient {
  final int hamlibModel;
  final String serialPort;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final String parity;
  final String handshake;

  final _HamlibBindings _b;
  Pointer _rig = nullptr;
  bool _opened = false;
  bool _disposed = false;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  HamlibFfiClient({
    required this.hamlibModel,
    this.serialPort = '',
    this.baudRate = 9600,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = 'none',
    this.handshake = 'none',
  }) : _b = _getBindings();

  /// Emits true when connected (rig opened), false when disconnected.
  Stream<bool> get connectionState => _connectionController.stream;

  /// Whether the rig is open and ready for commands.
  bool get isConnected => _opened && !_disposed;

  /// Initialize and open the rig.
  Future<void> connect() async {
    if (_disposed) throw StateError('HamlibFfiClient has been disposed');
    if (_opened) throw StateError('Already connected');

    _rig = _b.rigInit(hamlibModel);
    if (_rig == nullptr) {
      throw HamlibError(-1, 'rig_init');
    }

    // Configure serial port settings (before rig_open).
    if (hamlibModel > 2) {
      if (serialPort.isNotEmpty) {
        _setConf('rig_pathname', serialPort);
      }
      _setConf('serial_speed', baudRate.toString());
      if (dataBits != 8) _setConf('data_bits', dataBits.toString());
      if (stopBits != 1) _setConf('stop_bits', stopBits.toString());
      if (parity != 'none') {
        _setConf('serial_parity',
            parity[0].toUpperCase() + parity.substring(1));
      }
      if (handshake != 'none') {
        _setConf('serial_handshake',
            handshake[0].toUpperCase() + handshake.substring(1));
      }
    }

    final rc = _b.rigOpen(_rig);
    if (rc != 0) {
      _b.rigCleanup(_rig);
      _rig = nullptr;
      throw HamlibError(rc, 'rig_open');
    }

    _opened = true;
    if (!_disposed) _connectionController.add(true);
  }

  /// Close the rig connection.
  Future<void> disconnect() async {
    if (!_opened) return;
    _b.rigClose(_rig);
    _b.rigCleanup(_rig);
    _rig = nullptr;
    _opened = false;
    if (!_disposed) _connectionController.add(false);
  }

  /// Close and release all resources.
  Future<void> dispose() async {
    _disposed = true;
    if (_opened) {
      _b.rigClose(_rig);
      _b.rigCleanup(_rig);
      _rig = nullptr;
      _opened = false;
    }
    await _connectionController.close();
  }

  void _setConf(String name, String value) {
    final namePtr = name.toNativeUtf8();
    final token = _b.rigTokenLookup(_rig, namePtr);
    if (token <= 0) {
      malloc.free(namePtr);
      return; // Unknown token — skip silently.
    }
    final valPtr = value.toNativeUtf8();
    _b.rigSetConf(_rig, token, valPtr);
    malloc.free(namePtr);
    malloc.free(valPtr);
  }

  void _checkOpen() {
    if (!_opened || _disposed) throw StateError('Rig not connected');
  }

  // -- Frequency --

  /// Get the current VFO frequency in Hz.
  Future<int> getFrequency() async {
    _checkOpen();
    final freqPtr = malloc<Double>();
    try {
      final rc = _b.rigGetFreq(_rig, _rigVfoCurr, freqPtr);
      if (rc != 0) throw HamlibError(rc, 'rig_get_freq');
      return freqPtr.value.round();
    } finally {
      malloc.free(freqPtr);
    }
  }

  /// Set the VFO frequency in Hz.
  Future<void> setFrequency(int hz) async {
    _checkOpen();
    final rc = _b.rigSetFreq(_rig, _rigVfoCurr, hz.toDouble());
    if (rc != 0) throw HamlibError(rc, 'rig_set_freq');
  }

  // -- Mode --

  /// Get the current mode and passband width.
  Future<({String mode, int passband})> getMode() async {
    _checkOpen();
    final modePtr = malloc<Uint64>();
    final widthPtr = malloc<Int64>();
    try {
      final rc = _b.rigGetMode(_rig, _rigVfoCurr, modePtr, widthPtr);
      if (rc != 0) throw HamlibError(rc, 'rig_get_mode');
      final modeStr = _modeToString(modePtr.value);
      return (mode: modeStr, passband: widthPtr.value);
    } finally {
      malloc.free(modePtr);
      malloc.free(widthPtr);
    }
  }

  /// Set the mode and passband width.
  Future<void> setMode(String mode, {int passband = 0}) async {
    _checkOpen();
    final modeInt = _stringToMode(mode);
    final rc = _b.rigSetMode(_rig, _rigVfoCurr, modeInt, passband);
    if (rc != 0) throw HamlibError(rc, 'rig_set_mode');
  }

  // -- PTT --

  /// Get PTT state. Returns true if transmitting.
  Future<bool> getPtt() async {
    _checkOpen();
    final pttPtr = malloc<Int32>();
    try {
      final rc = _b.rigGetPtt(_rig, _rigVfoCurr, pttPtr);
      if (rc != 0) throw HamlibError(rc, 'rig_get_ptt');
      return pttPtr.value != _rigPttOff;
    } finally {
      malloc.free(pttPtr);
    }
  }

  /// Set PTT state.
  Future<void> setPtt(bool on) async {
    _checkOpen();
    final rc =
        _b.rigSetPtt(_rig, _rigVfoCurr, on ? _rigPttOn : _rigPttOff);
    if (rc != 0) throw HamlibError(rc, 'rig_set_ptt');
  }

  // -- VFO --

  /// Get the current VFO name (e.g. 'VFOA', 'VFOB').
  Future<String> getVfo() async {
    _checkOpen();
    final vfoPtr = malloc<Uint32>();
    try {
      final rc = _b.rigGetVfo(_rig, vfoPtr);
      if (rc != 0) throw HamlibError(rc, 'rig_get_vfo');
      return _vfoName(vfoPtr.value);
    } finally {
      malloc.free(vfoPtr);
    }
  }

  /// Set the current VFO.
  Future<void> setVfo(String vfo) async {
    _checkOpen();
    final rc = _b.rigSetVfo(_rig, _parseVfo(vfo));
    if (rc != 0) throw HamlibError(rc, 'rig_set_vfo');
  }

  // -- Split --

  /// Get split status.
  Future<({bool enabled, String txVfo})> getSplit() async {
    _checkOpen();
    final splitPtr = malloc<Int32>();
    final txVfoPtr = malloc<Uint32>();
    try {
      final rc =
          _b.rigGetSplitVfo(_rig, _rigVfoCurr, splitPtr, txVfoPtr);
      if (rc != 0) throw HamlibError(rc, 'rig_get_split_vfo');
      return (
        enabled: splitPtr.value != 0,
        txVfo: _vfoName(txVfoPtr.value),
      );
    } finally {
      malloc.free(splitPtr);
      malloc.free(txVfoPtr);
    }
  }

  /// Set split mode.
  Future<void> setSplit(bool enabled, {String txVfo = 'VFOB'}) async {
    _checkOpen();
    final rc = _b.rigSetSplitVfo(
        _rig, _rigVfoCurr, enabled ? 1 : 0, _parseVfo(txVfo));
    if (rc != 0) throw HamlibError(rc, 'rig_set_split_vfo');
  }

  // -- Rig info --

  /// Get rig info string.
  Future<String> getRigInfo() async {
    _checkOpen();
    final ptr = _b.rigGetInfo(_rig);
    if (ptr == nullptr) return '';
    return ptr.toDartString();
  }

  /// Get signal strength in dBFS (S-meter).
  Future<int> getSignalStrength() async {
    _checkOpen();
    final valPtr = malloc<Int32>();
    try {
      final rc =
          _b.rigGetLevel(_rig, _rigVfoCurr, _rigLevelStrength, valPtr);
      if (rc != 0) return 0;
      return valPtr.value;
    } finally {
      malloc.free(valPtr);
    }
  }

  // -- Mode conversion helpers --

  String _modeToString(int mode) {
    final ptr = _b.rigStrrmode(mode);
    if (ptr == nullptr) return '';
    return ptr.toDartString();
  }

  int _stringToMode(String mode) {
    final ptr = mode.toNativeUtf8();
    try {
      return _b.rigParseMode(ptr);
    } finally {
      malloc.free(ptr);
    }
  }
}
