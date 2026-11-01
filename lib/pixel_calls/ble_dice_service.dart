import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

class PixelsBluetoothIds {
  static const String dieService = 'a6b90001-7a5a-43f2-a962-350c8edc9b5b';
  static const String dieNotifyCharacteristic =
      'a6b90002-7a5a-43f2-a962-350c8edc9b5b';

  static const String legacyDieService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String legacyDieNotifyCharacteristic =
      '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
}

class BleDiceService {
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<Uint8List>? _notifySub;

  BleDevice? _connectedDevice;
  BleCharacteristic? _notifyCharacteristic;

  final _rollController = StreamController<int>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<int> get rollStream => _rollController.stream;
  Stream<String> get statusStream => _statusController.stream;

  bool _usingLegacyService = false;
  static const bool _enableDebugLogs = false;

  Future<void> connect() async {
    final availability = await UniversalBle.getBluetoothAvailabilityState();
    if (availability != AvailabilityState.poweredOn) {
      throw Exception('Bluetooth appears to be off');
    }

    _statusController.add('Scanning for Pixels die...');
    await _scanSub?.cancel();

    final device = await _findFirstDiceDevice();
    if (device == null) {
      throw Exception('No compatible Pixels die found nearby.');
    }

    final displayName =
        (device.name == null || device.name!.isEmpty) ? 'dice' : device.name!;
    _statusController.add('Connecting to $displayName...');
    await _connectAndSubscribe(device, advertisedServices: device.services);
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;

    await _connectionSub?.cancel();
    _connectionSub = null;

    await _scanSub?.cancel();
    _scanSub = null;

    if (_notifyCharacteristic != null && _connectedDevice != null) {
      try {
        await _notifyCharacteristic!.unsubscribe();
      } catch (_) {}
      _notifyCharacteristic = null;
    }

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }

    try {
      await UniversalBle.stopScan();
    } catch (_) {}
  }

  Future<BleDevice?> _findFirstDiceDevice() async {
    final completer = Completer<BleDevice?>();

    _scanSub = UniversalBle.scanStream.listen(
      (device) {
        final serviceMatches = _containsService(
              device.services,
              PixelsBluetoothIds.dieService,
            ) ||
            _containsService(
              device.services,
              PixelsBluetoothIds.legacyDieService,
            );
        final name = (device.name ?? '').toLowerCase();
        final nameLooksLikePixels =
            name.contains('pixel') || name.contains('die');

        if (!completer.isCompleted &&
            (serviceMatches || nameLooksLikePixels)) {
          completer.complete(device);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
    );

    await UniversalBle.startScan();

    final result = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );

    await _scanSub?.cancel();
    _scanSub = null;
    await UniversalBle.stopScan();
    return result;
  }

  Future<void> _connectAndSubscribe(
    BleDevice device, {
    required List<String> advertisedServices,
  }) async {
    _connectedDevice = device;

    final serviceId = await _resolveServiceId(device, advertisedServices);
    _usingLegacyService =
        BleUuidParser.compareStrings(serviceId, PixelsBluetoothIds.legacyDieService);

    final notifyId = _usingLegacyService
        ? PixelsBluetoothIds.legacyDieNotifyCharacteristic
        : PixelsBluetoothIds.dieNotifyCharacteristic;

    await _connectionSub?.cancel();
    _connectionSub = device.connectionStream.listen(
      (isConnected) {
        if (isConnected) {
          _statusController.add(_usingLegacyService
              ? 'Connected (legacy BLE profile)'
              : 'Connected (BLE profile)');
        } else {
          _statusController.add('Disconnected');
        }
      },
      onError: (Object e) {
        _statusController.add('Connection error: $e');
      },
    );

    await device.connect(timeout: const Duration(seconds: 12));

    final characteristic = await device.getCharacteristic(
      notifyId,
      service: serviceId,
    );
    _notifyCharacteristic = characteristic;

    await characteristic.notifications.subscribe();

    await _notifySub?.cancel();
    _notifySub = characteristic.onValueReceived.listen(
      (bytes) {
        if (_enableDebugLogs) {
          final profile = _usingLegacyService ? 'legacy' : 'die';
          print('[BLE][$profile] notify bytes: $bytes');
        }
        final maybeRoll = _tryParseRoll(bytes);
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

  Future<String> _resolveServiceId(
    BleDevice device,
    List<String> advertisedServices,
  ) async {
    if (_containsService(
      advertisedServices,
      PixelsBluetoothIds.legacyDieService,
    )) {
      return PixelsBluetoothIds.legacyDieService;
    }
    if (_containsService(advertisedServices, PixelsBluetoothIds.dieService)) {
      return PixelsBluetoothIds.dieService;
    }

    final discovered = await device.discoverServices();
    for (final service in discovered) {
      if (BleUuidParser.compareStrings(
        service.uuid,
        PixelsBluetoothIds.dieService,
      )) {
        return PixelsBluetoothIds.dieService;
      }
    }
    for (final service in discovered) {
      if (BleUuidParser.compareStrings(
        service.uuid,
        PixelsBluetoothIds.legacyDieService,
      )) {
        return PixelsBluetoothIds.legacyDieService;
      }
    }

    throw Exception('No compatible Pixels die service found.');
  }

  bool _containsService(List<String> services, String serviceUuid) {
    return services.any(
      (uuid) => BleUuidParser.compareStrings(uuid, serviceUuid),
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

    if (bytes.length >= 3 && bytes[0] == rollStateMessageType) {
      final state = bytes[1];
      final faceIndex = bytes[2];
      if (_enableDebugLogs) {
        print(
          '[BLE] decoded direct message type=${bytes[0]} state=$state faceIndex=$faceIndex',
        );
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
