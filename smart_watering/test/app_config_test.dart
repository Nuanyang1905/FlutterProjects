import 'package:flutter_test/flutter_test.dart';
import 'package:smart_watering/config/app_config.dart';

void main() {
  test('preserves http api settings through json roundtrip', () {
    const config = AppConfig(
      uid: 'uid123',
      controlTopic: 'plant001',
      reportTopic: 'plant001up',
      type: 1,
    );

    final encoded = config.toJson();
    final decoded = AppConfig.fromJson(encoded);

    expect(decoded.uid, 'uid123');
    expect(decoded.controlTopic, 'plant001');
    expect(decoded.reportTopic, 'plant001up');
    expect(decoded.type, 1);
  });
}
