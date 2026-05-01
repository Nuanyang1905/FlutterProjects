import 'package:flutter_test/flutter_test.dart';
import 'package:smart_watering/models/device_state.dart';

void main() {
  test('parses v2 JSON device payload', () {
    const payload =
        '{"ver":2,"type":"status","hum":45,"raw":678,"pump":0,"mode":"auto","th_low":30,"th_high":60,"lock":1,"sensor_ok":1}';
    final state = DeviceState.parse(payload);

    expect(state.protocolVersion, 2);
    expect(state.humidity, 45);
    expect(state.rawValue, 678);
    expect(state.isAutoMode, isTrue);
    expect(state.isPumpOn, isFalse);
    expect(state.thL, 30);
    expect(state.thH, 60);
    expect(state.isLocked, isTrue);
    expect(state.isSensorOk, isTrue);
  });

  test('parses legacy JSON field names for compatibility', () {
    const payload =
        '{"hum":45,"mode":"manual","pump":1,"th_L":35,"th_H":65,"lock":0}';
    final state = DeviceState.parse(payload);

    expect(state.protocolVersion, 0);
    expect(state.isAutoMode, isFalse);
    expect(state.isPumpOn, isTrue);
    expect(state.thL, 35);
    expect(state.thH, 65);
  });

  test('parses legacy payload and converts to dual-threshold', () {
    const payload = '#45#1#30#1';
    final state = DeviceState.parse(payload);

    expect(state.protocolVersion, 0);
    expect(state.humidity, 45);
    expect(state.isPumpOn, isTrue);
    expect(state.isAutoMode, isTrue);
    expect(state.thL, 30);
    expect(state.thH, 50);
    expect(state.isLocked, isFalse);
    expect(state.isSensorOk, isTrue);
  });

  test('returns null for invalid payload in tryParse', () {
    final state = DeviceState.tryParse('invalid');
    expect(state, isNull);
  });
}
