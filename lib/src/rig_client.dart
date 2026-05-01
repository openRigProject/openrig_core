/// Abstract interface for rig control clients.
///
/// Both [RigctldClient] (TCP) and [HamlibFfiClient] (direct FFI) implement
/// this interface, allowing the UI and RigManager to work with either
/// connection type transparently.
library;

import 'dart:async';

/// Common rig control interface.
abstract interface class RigClient {
  /// Emits true when connected, false when disconnected.
  Stream<bool> get connectionState;

  /// Whether the client is currently connected/open.
  bool get isConnected;

  /// Connect to / open the rig.
  Future<void> connect();

  /// Disconnect from / close the rig.
  Future<void> disconnect();

  /// Release all resources.
  Future<void> dispose();

  // -- Frequency --
  Future<int> getFrequency();
  Future<void> setFrequency(int hz);

  // -- Mode --
  Future<({String mode, int passband})> getMode();
  Future<void> setMode(String mode, {int passband});

  // -- PTT --
  Future<bool> getPtt();
  Future<void> setPtt(bool on);

  // -- VFO --
  Future<String> getVfo();
  Future<void> setVfo(String vfo);

  // -- Split --
  Future<({bool enabled, String txVfo})> getSplit();
  Future<void> setSplit(bool enabled, {String txVfo});

  // -- Info --
  Future<String> getRigInfo();
  Future<int> getSignalStrength();
}
