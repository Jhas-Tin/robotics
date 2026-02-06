import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const RobotApp());
}

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const RobotHome(),
    );
  }
}

class RobotHome extends StatefulWidget {
  const RobotHome({super.key});

  @override
  State<RobotHome> createState() => _RobotHomeState();
}

class _RobotHomeState extends State<RobotHome> {
  final String baseUrl = "http://192.168.4.1";
  final String cameraUrl = "http://192.168.4.1:81/stream";

  bool flashOn = false;
  bool cameraOn = true;
  bool turbo = false;
  int speed = 150;

  Offset joystickOffset = Offset.zero;
  final double joystickRadius = 60;

  Future<void> send(String cmd) async {
    try {
      await http.get(Uri.parse("$baseUrl/$cmd"));
    } catch (_) {}
  }

  Future<void> sendSpeed() async {
    try {
      await http.get(Uri.parse("$baseUrl/speed?value=$speed"));
    } catch (_) {}
  }

  Widget controlButton(
      IconData icon,
      Color color, {
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget joystick() {
    return GestureDetector(
      onPanStart: (_) => sendSpeed(),
      onPanUpdate: (details) {
        setState(() {
          joystickOffset += details.delta;
          joystickOffset = Offset(
            joystickOffset.dx.clamp(-joystickRadius, joystickRadius),
            joystickOffset.dy.clamp(-joystickRadius, joystickRadius),
          );
        });

        if (joystickOffset.dx.abs() > joystickOffset.dy.abs()) {
          send(joystickOffset.dx > 0 ? "right" : "left");
        } else {
          send(joystickOffset.dy > 0 ? "backward" : "forward");
        }
      },
      onPanEnd: (_) {
        setState(() => joystickOffset = Offset.zero);
        send("stop");
      },
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white24,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 1.5),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10, width: 1),
              ),
            ),
            Transform.translate(
              offset: joystickOffset,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.6),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    const BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(2, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.white24, width: 2),
                ),
              ),
            ),
            if (joystickOffset != Offset.zero)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.2),
                        blurRadius: 24,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    controlButton(
                      cameraOn ? Icons.videocam : Icons.videocam_off,
                      cameraOn ? Colors.greenAccent : Colors.grey.shade700,
                      onTap: () {
                        setState(() => cameraOn = !cameraOn);
                      },
                    ),

                    const Text(
                      "SPEED",
                      style: TextStyle(
                        letterSpacing: 2,
                        color: Colors.white70,
                      ),
                    ),
                    Slider(
                      value: speed.toDouble(),
                      min: 0,
                      max: 255,
                      divisions: 255,
                      label: "$speed",
                      onChanged: (v) {
                        setState(() => speed = v.toInt());
                        sendSpeed();
                      },
                    ),

                    controlButton(
                      flashOn ? Icons.flash_on : Icons.flash_off,
                      flashOn ? Colors.orangeAccent : Colors.grey.shade700,
                      onTap: () {
                        send(flashOn ? "flash/off" : "flash/on");
                        setState(() => flashOn = !flashOn);
                      },
                    ),

                    GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          turbo = true;
                          speed = 255;
                        });
                        sendSpeed();
                      },
                      onTapUp: (_) {
                        setState(() {
                          turbo = false;
                          speed = 150;
                        });
                        sendSpeed();
                      },
                      child: controlButton(
                        Icons.whatshot,
                        turbo ? Colors.redAccent : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 16),
                  ],
                  color: Colors.black, // keeps the shadow effect
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: cameraOn
                      ? Mjpeg(
                    stream: cameraUrl,
                    isLive: true,
                    error: (_, __, ___) =>
                    const Center(child: Text("Camera Error")),
                  )
                      : const SizedBox.shrink(), // hides content but keeps layout
                ),
              ),
            ),

            /// ➡ RIGHT JOYSTICK
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: joystick(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
