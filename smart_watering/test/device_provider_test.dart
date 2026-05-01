import 'package:flutter_test/flutter_test.dart';
import 'package:smart_watering/models/device_state.dart';
import 'package:smart_watering/providers/device_provider.dart';
import 'package:smart_watering/services/bemfa_api_service.dart';

import 'test_support/fake_bemfa_api_service.dart';

void main() {
  DeviceProvider buildProvider(FakeBemfaApiService api) {
    return DeviceProvider(
      apiService: api,
      pollInterval: const Duration(days: 1),
    );
  }

  group('DeviceProvider.setManualMode', () {
    test('sends manual mode command when switching from auto', () async {
      final api = FakeBemfaApiService()..online = true;
      api.enqueueState(
        DeviceState.defaultState.copyWith(
          isPumpOn: true,
          isAutoMode: true,
          lastUpdate: DateTime.now(),
        ),
      );
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      final result = await provider.setManualMode();

      expect(result, isTrue);
      expect(api.lastCommand, 'manual');
      expect(provider.deviceState.isAutoMode, isFalse);
      expect(provider.deviceState.isPumpOn, isTrue);
    });

    test('does not change pump state when entering manual mode', () async {
      final api = FakeBemfaApiService()..online = true;
      api.enqueueState(
        DeviceState.defaultState.copyWith(
          isPumpOn: false,
          isAutoMode: true,
          lastUpdate: DateTime.now(),
        ),
      );
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      final result = await provider.setManualMode();

      expect(result, isTrue);
      expect(api.lastCommand, 'manual');
      expect(provider.deviceState.isAutoMode, isFalse);
      expect(provider.deviceState.isPumpOn, isFalse);
    });
  });

  group('DeviceProvider.pump commands', () {
    test(
      'optimistically updates pump state after turnOnPump succeeds',
      () async {
        final api = FakeBemfaApiService()..online = true;
        api.enqueueState(
          DeviceState.defaultState.copyWith(
            isPumpOn: false,
            isAutoMode: false,
            lastUpdate: DateTime.now(),
          ),
        );
        final provider = buildProvider(api);
        addTearDown(provider.dispose);

        await provider.connect();
        await Future<void>.delayed(Duration.zero);

        final result = await provider.turnOnPump();

        expect(result, isTrue);
        expect(api.lastCommand, 'on');
        expect(provider.deviceState.isPumpOn, isTrue);
      },
    );

    test(
      'optimistically updates pump state after turnOffPump succeeds',
      () async {
        final api = FakeBemfaApiService()..online = true;
        api.enqueueState(
          DeviceState.defaultState.copyWith(
            isPumpOn: true,
            isAutoMode: false,
            lastUpdate: DateTime.now(),
          ),
        );
        final provider = buildProvider(api);
        addTearDown(provider.dispose);

        await provider.connect();
        await Future<void>.delayed(Duration.zero);

        final result = await provider.turnOffPump();

        expect(result, isTrue);
        expect(api.lastCommand, 'off');
        expect(provider.deviceState.isPumpOn, isFalse);
      },
    );

    test('keeps local pump state when a stale device echo arrives', () async {
      final api = FakeBemfaApiService()..online = true;
      api.enqueueState(
        DeviceState.defaultState.copyWith(
          isPumpOn: true,
          isAutoMode: false,
          lastUpdate: DateTime.now(),
        ),
      );
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      final result = await provider.turnOffPump();
      api.enqueueState(
        DeviceState.defaultState.copyWith(
          isPumpOn: true,
          isAutoMode: false,
          lastUpdate: DateTime.now(),
        ),
      );

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      expect(result, isTrue);
      expect(provider.deviceState.isPumpOn, isFalse);
    });
  });

  group('DeviceProvider.threshold debounce', () {
    test('rapid setThreshold calls only send the last command', () async {
      final api = FakeBemfaApiService()..online = true;
      api.enqueueState(
        DeviceState.defaultState.copyWith(
          thL: 20,
          thH: 50,
          lastUpdate: DateTime.now(),
        ),
      );
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      api.lastCommand = null;

      provider.setThreshold(10, 40);
      provider.setThreshold(20, 50);
      provider.setThreshold(30, 60);

      await Future.delayed(const Duration(milliseconds: 600));

      expect(api.lastCommand, 'set:30,60');
    });

    test('previous timer is cancelled on rapid setThreshold calls', () async {
      final api = FakeBemfaApiService()..online = true;
      api.enqueueState(
        DeviceState.defaultState.copyWith(
          thL: 20,
          thH: 50,
          lastUpdate: DateTime.now(),
        ),
      );

      int commandCount = 0;
      api.sendCommandFn = (cmd) async {
        commandCount++;
        return true;
      };

      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      provider.setThreshold(10, 40);
      provider.setThreshold(20, 50);
      provider.setThreshold(30, 60);

      await Future.delayed(const Duration(milliseconds: 600));

      expect(commandCount, 1);
    });

    test('setThreshold does not send command when disconnected', () async {
      final api = FakeBemfaApiService()..online = false;
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      api.lastCommand = null;

      final result = await provider.setThreshold(30, 60);

      await Future.delayed(const Duration(milliseconds: 600));

      expect(result, isFalse);
      expect(api.lastCommand, isNull);
    });
  });

  group('DeviceProvider.error state recovery', () {
    test('offline device sets disconnected state', () async {
      final api = FakeBemfaApiService()..online = false;
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      expect(provider.connectionState, AppDeviceConnectionState.disconnected);
      expect(provider.isConnected, isFalse);
    });

    test('checkOnline exception sets failed state', () async {
      final api = FakeBemfaApiService()
        ..online = true
        ..throwOnCheckOnline = true;
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      expect(provider.connectionState, AppDeviceConnectionState.failed);
      expect(provider.isConnected, isFalse);
    });

    test('successful reconnect after offline restores online state', () async {
      final api = FakeBemfaApiService()..online = false;
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      expect(provider.connectionState, AppDeviceConnectionState.disconnected);

      api.online = true;
      api.enqueueState(
        DeviceState.defaultState.copyWith(
          humidity: 50,
          lastUpdate: DateTime.now(),
        ),
      );

      await provider.reconnect();
      await Future<void>.delayed(Duration.zero);

      expect(provider.connectionState, AppDeviceConnectionState.online);
      expect(provider.isConnected, isTrue);
    });

    test('pump operation returns false when disconnected', () async {
      final api = FakeBemfaApiService()..online = false;
      final provider = buildProvider(api);
      addTearDown(provider.dispose);

      await provider.connect();
      await Future<void>.delayed(Duration.zero);

      final turnOnResult = await provider.turnOnPump();
      expect(turnOnResult, isFalse);

      final turnOffResult = await provider.turnOffPump();
      expect(turnOffResult, isFalse);

      final modeResult = await provider.setAutoMode();
      expect(modeResult, isFalse);
    });
  });
}
