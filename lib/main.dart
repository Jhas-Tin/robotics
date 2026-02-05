import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

void main() {
  runApp(const RobotApp());
}

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0E11),
      ),
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
  int speed = 150; // initial speed (0-255)
  bool turbo = false;

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
      String cmd, {
        double size = 64,
        Color color = const Color(0xFF1F6BFF),
      }) {
    return GestureDetector(
      onTapDown: (_) {
        sendSpeed(); // update speed before moving
        send(cmd);
      },
      onTapUp: (_) => send("stop"),
      onTapCancel: () => send("stop"),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(.85), color],
          ),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(3, 5)),
          ],
        ),
        child: Icon(icon, size: size * .45, color: Colors.white),
      ),
    );
  }

  /// 🎮 D-PAD
  Widget dPad() {
    return Column(
      children: [
        controlButton(Icons.keyboard_arrow_up, "forward"),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            controlButton(Icons.keyboard_arrow_left, "left"),
            const SizedBox(width: 14),
            controlButton(
              Icons.stop,
              "stop",
              color: Colors.redAccent,
            ),
            const SizedBox(width: 14),
            controlButton(Icons.keyboard_arrow_right, "right"),
          ],
        ),
        const SizedBox(height: 10),
        controlButton(Icons.keyboard_arrow_down, "backward"),
      ],
    );
  }

  /// 🔦 Small Floating Flash Button
  Widget flashButton() {
    return GestureDetector(
      onTap: () {
        send(flashOn ? "flash/off" : "flash/on");
        setState(() => flashOn = !flashOn);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: flashOn ? Colors.orangeAccent : Colors.black54,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 6),
          ],
        ),
        child: Icon(
          flashOn ? Icons.flash_on : Icons.flash_off,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  /// ⚡ Turbo Button
  Widget turboButton() {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          turbo = true;
          speed = 255; // full speed
        });
        sendSpeed();
      },
      onTapUp: (_) {
        setState(() {
          turbo = false;
          speed = 150; // back to normal
        });
        sendSpeed();
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: turbo ? Colors.redAccent : Colors.grey[800],
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 6),
          ],
        ),
        child: const Icon(Icons.whatshot, color: Colors.white, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "ESP32-CAM CONTROLLER",
          style: TextStyle(letterSpacing: 1.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// 📷 CAMERA + FLASH OVERLAY
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black87, blurRadius: 12),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Mjpeg(
                          stream: cameraUrl,
                          isLive: true,
                          error: (_, __, ___) =>
                          const Center(child: Text("Camera error")),
                        ),
                      ),
                    ),
                  ),

                  /// Flash button position
                  Positioned(
                    bottom: 22,
                    right: 22,
                    child: flashButton(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// 🎮 CONTROLLER PANEL
              Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151A),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 20),
                  ],
                ),
                child: Column(
                  children: [
                    dPad(),

                    const SizedBox(height: 20),

                    /// 🟡 Speed Slider
                    Column(
                      children: [
                        const Text(
                          "Speed",
                          style: TextStyle(color: Colors.white70),
                        ),
                        Slider(
                          value: speed.toDouble(),
                          min: 0,
                          max: 255,
                          divisions: 255,
                          label: "$speed",
                          activeColor: Colors.blueAccent,
                          inactiveColor: Colors.grey[700],
                          onChanged: (double value) {
                            setState(() => speed = value.toInt());
                            sendSpeed();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// 🔥 Turbo Button
                    turboButton(),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
