import '../service/ble_service.dart';

class CommandService {
  static const int cmdAngle = 0x01;
  static const int cmdMove = 0x02;
  static const int cmdLineModule = 0x03;

  static void sendAngleCmd({
    required int rot,
    required int b,
    required int c,
    required int grip,
    required int line,
  }) {
    final bytes = List<int>.filled(8, 0);
    bytes[0] = 0xA5;
    bytes[1] = 0xA5;
    bytes[2] = cmdAngle;
    bytes[3] = rot;
    bytes[4] = b;
    bytes[5] = c;
    bytes[6] = grip;
    bytes[7] = line;
    BleService.instance.sendCommand(bytes);
  }

  static void sendLineModuleCmd(int location) {
    final bytes = List<int>.filled(5, 0);
    bytes[0] = 0xA5;
    bytes[1] = 0xA5;
    bytes[2] = cmdLineModule;
    bytes[3] = location ~/ 256;
    bytes[4] = location % 256;
    BleService.instance.sendCommand(bytes);
  }

  static void sendMoveCmd({
    required int moveX,
    required int moveY,
    required int moveZ,
  }) {
    final bytes = List<int>.filled(6, 0);
    bytes[0] = 0xA5;
    bytes[1] = 0xA5;
    bytes[2] = cmdMove;
    bytes[3] = moveX;
    bytes[4] = moveY;
    bytes[5] = moveZ;
    BleService.instance.sendCommand(bytes);
  }

  /// Sends a hardcoded angle reset command (all joints to default positions).
  static void sendAngleResetCmd() {
    final bytes = List<int>.filled(8, 0);
    bytes[0] = 0xA5;
    bytes[1] = 0xA5;
    bytes[2] = cmdAngle;
    bytes[3] = 90;
    bytes[4] = 40;
    bytes[5] = 130;
    bytes[6] = 0;
    bytes[7] = 0;
    BleService.instance.sendCommand(bytes);
  }
}
