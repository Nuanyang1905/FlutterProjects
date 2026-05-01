import 'package:flutter/material.dart';

class DirectionPad extends StatefulWidget {
  final void Function(int moveX, int moveY, int moveZ)? onDirectionChange;

  const DirectionPad({super.key, this.onDirectionChange});

  @override
  State<DirectionPad> createState() => _DirectionPadState();
}

class _DirectionPadState extends State<DirectionPad> {
  void _handleDown(int moveX, int moveY, int moveZ) {
    widget.onDirectionChange?.call(moveX, moveY, moveZ);
  }

  void _handleUp() {
    widget.onDirectionChange?.call(0, 0, 0);
  }

  Widget _directionButton({
    required IconData icon,
    required int moveX,
    required int moveY,
    required int moveZ,
    Color? color,
  }) {
    return Listener(
      onPointerDown: (_) => _handleDown(moveX, moveY, moveZ),
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color ?? Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            Column(
              children: [
                _buildLabel('上'),
                _directionButton(
                  icon: Icons.arrow_upward,
                  moveX: 0,
                  moveY: 1,
                  moveZ: 0,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(width: 80),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                _buildLabel('左'),
                _directionButton(
                  icon: Icons.arrow_back,
                  moveX: 0,
                  moveY: 0,
                  moveZ: 1,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                _buildLabel('停止'),
                _directionButton(
                  icon: Icons.home,
                  moveX: 0,
                  moveY: 0,
                  moveZ: 0,
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                _buildLabel('右'),
                _directionButton(
                  icon: Icons.arrow_forward,
                  moveX: 0,
                  moveY: 0,
                  moveZ: -1,
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            Column(
              children: [
                _buildLabel('下'),
                _directionButton(
                  icon: Icons.arrow_downward,
                  moveX: 0,
                  moveY: -1,
                  moveZ: 0,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(width: 80),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                _buildLabel('前'),
                _directionButton(
                  icon: Icons.arrow_back,
                  moveX: -1,
                  moveY: 0,
                  moveZ: 0,
                  color: Colors.teal,
                ),
              ],
            ),
            const SizedBox(width: 32),
            Column(
              children: [
                _buildLabel('后'),
                _directionButton(
                  icon: Icons.arrow_forward,
                  moveX: 1,
                  moveY: 0,
                  moveZ: 0,
                  color: Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
