import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class PixelsBluetoothIds {
  static const String dieService = 'a6b90001-7a5a-43f2-a962-350c8edc9b5b';
  static const String dieNotifyCharacteristic =
      'a6b90002-7a5a-43f2-a962-350c8edc9b5b';

  static const String legacyDieService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String legacyDieNotifyCharacteristic =
      '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
}

class BleDiceService {
  BleDiceService({FlutterReactiveBle? ble})
      : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;

  final _rollController = StreamController<int>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<int> get rollStream => _rollController.stream;
  Stream<String> get statusStream => _statusController.stream;

  bool _usingLegacyService = false;
  static const bool _enableDebugLogs = false;

  static final Uuid _dieServiceUuid = Uuid.parse(PixelsBluetoothIds.dieService);
  static final Uuid _legacyServiceUuid =
      Uuid.parse(PixelsBluetoothIds.legacyDieService);

  Future<void> connect() async {
    _statusController.add('Scanning for Pixels die...');
    await _scanSub?.cancel();

    final device = await _findFirstDiceDevice();
    if (device == null) {
      throw Exception('No compatible Pixels die found nearby.');
    }

    _statusController.add('Connecting to ${device.name.isEmpty ? 'dice' : device.name}...');
    await _connectAndSubscribe(device.id, advertisedServices: device.serviceUuids);
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connectionSub?.cancel();
    await _scanSub?.cancel();
  }

  Future<DiscoveredDevice?> _findFirstDiceDevice() async {
    final completer = Completer<DiscoveredDevice?>();

    _scanSub = _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
      (device) {
        final serviceMatches = device.serviceUuids.any(
          (uuid) => uuid == _dieServiceUuid || uuid == _legacyServiceUuid,
        );
        final name = device.name.toLowerCase();
        final nameLooksLikePixels = name.contains('pixel') || name.contains('die');

        if (!completer.isCompleted && (serviceMatches || nameLooksLikePixels)) {
          completer.complete(device);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
    );

    final result = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );

    await _scanSub?.cancel();
    return result;
  }

  Future<void> _connectAndSubscribe(
    String deviceId, {
    required List<Uuid> advertisedServices,
  }) async {
    _usingLegacyService = advertisedServices.contains(_legacyServiceUuid);

    final serviceUuid = Uuid.parse(
      _usingLegacyService
          ? PixelsBluetoothIds.legacyDieService
          : PixelsBluetoothIds.dieService,
    );
    final notifyUuid = Uuid.parse(
      _usingLegacyService
          ? PixelsBluetoothIds.legacyDieNotifyCharacteristic
          : PixelsBluetoothIds.dieNotifyCharacteristic,
    );

    final connectionReady = Completer<void>();

    await _connectionSub?.cancel();
    _connectionSub = _ble
        .connectToDevice(
          id: deviceId,
          connectionTimeout: const Duration(seconds: 12),
        )
        .listen(
      (update) async {
        if (update.connectionState == DeviceConnectionState.connected &&
            !connectionReady.isCompleted) {
          _statusController.add(_usingLegacyService
              ? 'Connected (legacy BLE profile)'
              : 'Connected (BLE profile)');
          connectionReady.complete();
        }
        if (update.connectionState == DeviceConnectionState.disconnected) {
          _statusController.add('Disconnected');
        }
      },
      onError: (Object e) {
        if (!connectionReady.isCompleted) {
          connectionReady.completeError(e);
        }
      },
    );

    await connectionReady.future;

    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: notifyUuid,
      deviceId: deviceId,
    );

    await _notifySub?.cancel();
    _notifySub = _ble.subscribeToCharacteristic(characteristic).listen(
      (bytes) {
        if (_enableDebugLogs) {
          final profile = _usingLegacyService ? 'legacy' : 'die';
          print('[BLE][$profile] notify bytes: $bytes');
        }
        final maybeRoll = _tryParseRoll(Uint8List.fromList(bytes));
        if (maybeRoll != null) {
          if (_enableDebugLogs) {
            print('[BLE] parsed roll: $maybeRoll');
          }
          _rollController.add(maybeRoll);
        } else if (_enableDebugLogs) {
          print('[BLE] no roll parsed from payload');
        }
      },
      onError: (Object e) {
        _statusController.add('Notification error: $e');
      },
    );
  }

  int? _tryParseRoll(Uint8List bytes) {
    // Pixels message hints from vendor repo:
    // - MessageTypeValues.rollState appears to be 3 (none=0, whoAreYou=1, iAmADie=2, rollState=3).
    // - RollState payload is [type, state, faceIndex].
    // - Face index is zero-based, so displayed roll is faceIndex + 1.
    //
    // We only accept explicit completed-roll events.
    // State mapping: rolled=1, handling=2, rolling=3, crooked=4, onFace=5.
    // Accepting onFace/crooked causes extra events while being picked up or resting.
    const int rollStateMessageType = 3;
    const int rolledState = 1;

    // Primary path: exact framing seen in deserializeMessage(dataView).
    // byte[0] is the message type, and rollState message is [type, state, faceIndex].
    if (bytes.length >= 3 && bytes[0] == rollStateMessageType) {
      final state = bytes[1];
      final faceIndex = bytes[2];
      if (_enableDebugLogs) {
        print('[BLE] decoded direct message type=${bytes[0]} state=$state faceIndex=$faceIndex');
      }
      if (state == rolledState) {
        final roll = faceIndex + 1;
        if (roll >= 1 && roll <= 20) {
          return roll;
        }
      }
      return null;
    }
    return null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _rollController.close();
    await _statusController.close();
  }
}
