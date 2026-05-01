import 'package:flutter/material.dart';

import '../service/command_service.dart';
import '../widget/direction_pad.dart';

class MovePage extends StatelessWidget {
  const MovePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('方向控制'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DirectionPad(
              onDirectionChange: (moveX, moveY, moveZ) {
                CommandService.sendMoveCmd(
                  moveX: moveX,
                  moveY: moveY,
                  moveZ: moveZ,
                );
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                CommandService.sendAngleResetCmd();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('复位'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
