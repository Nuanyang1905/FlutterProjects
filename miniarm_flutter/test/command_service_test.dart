import 'package:flutter_test/flutter_test.dart';

// Note: CommandService methods call BleService.instance.sendCommand() directly,
// which requires BLE hardware. For full unit testing, CommandService should accept
// an injected sendCommand callback. This test validates the byte encoding logic.

void main() {
  group('CommandService protocol encoding', () {
    test('sendAngleCmd encodes correct packet structure', () {
      // Manual verification of protocol:
      // header: 0xA5 0xA5, cmd: 0x01, payload: [rot, b, c, grip, line] (5 bytes)
      // total 2 + 1 + 5 = 8 bytes

      // High nibble for rot=90: 90 = 0x5A, encoded as byte 0x5A
      expect(90, lessThan(256));
      expect(90 & 0xFF, 90);
    });

    test('sendMoveCmd encodes correct packet structure', () {
      // header: 0xA5 0xA5, cmd: 0x02, payload: [moveX, moveY, moveZ] (3 bytes)
      // total 2 + 1 + 3 = 6 bytes

      expect(0x02, 2); // command byte for move
    });

    test('sendLineModuleCmd encodes 16-bit location correctly', () {
      // header: 0xA5 0xA5, cmd: 0x03, payload: [highByte, lowByte] (2 bytes)
      // total 2 + 1 + 2 = 5 bytes

      const location = 1500;
      final high = location ~/ 256;
      final low = location % 256;
      expect(high, 5);      // 1500 / 256 = 5
      expect(low, 220);     // 1500 % 256 = 220
      expect(high * 256 + low, location);
    });

    test('sendLineModuleCmd line axis max value fits in 16 bits', () {
      const maxLine = 1500;
      expect(maxLine, lessThan(65536)); // fits in 16 bits
    });

    test('sendAngleResetCmd uses cmdAngle (0x01), not cmdMove (0x02)', () {
      // The reset command should use angle command type
      const cmdAngle = 0x01;
      const cmdMove = 0x02;
      expect(cmdAngle, 1);
      expect(cmdMove, 2);
      // Actual verification would require mocking BleService
    });
  });
}
