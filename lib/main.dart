import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const DspApp());

class DspApp extends StatelessWidget {
  const DspApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B111E),
      ),
      home: const DspControlScreen(),
    );
  }
}

class DspControlScreen extends StatefulWidget {
  const DspControlScreen({super.key});
  @override
  State<DspControlScreen> createState() => _DspControlScreenState();
}

class _DspControlScreenState extends State<DspControlScreen> {
  Color accentColor = const Color(0xFF00F2FE);

  // ESP32 IP Address (Change or set via dialog)
  String espIp = "192.168.43.100"; // Default, editable in app
  WebSocketChannel? channel;
  bool isConnected = false;
  bool isConnecting = false;
  Timer? reconnectTimer;

  // Audio & DSP State
  String inputSource = "BT AUDIO";
  String sleepTimer = "OFF";
  double masterVol = 4; // Startup 4/29
  double subVol = 20;
  double bass = 0;
  double mid = 0;
  double treble = 0;
  double gain = 15;
  double loudness = 8;
  String subCutoff = "80 Hz (Tight Bass)";
  String bassCenter = "60 Hz (Sub Bass)";
  String trebleCutoff = "12.5 kHz (Crisp)";

  bool toneOpen = false;
  bool filterOpen = false;

  @override
  void initState() {
    super.initState();
    connectWebSocket();
  }

  @override
  void dispose() {
    reconnectTimer?.cancel();
    channel?.sink.close();
    super.dispose();
  }

  void connectWebSocket() {
    if (isConnected || isConnecting) return;
    setState(() => isConnecting = true);

    try {
      final wsUrl = Uri.parse('ws://$espIp/ws');
      channel = WebSocketChannel.connect(wsUrl);

      channel!.stream.listen(
        (message) {
          if (!isConnected) {
            setState(() {
              isConnected = true;
              isConnecting = false;
            });
          }
          _handleIncomingData(message.toString());
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          _handleDisconnect();
        },
      );

      // Request current status
      sendWsPacket("REQ_SYNC", "");
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (mounted) {
      setState(() {
        isConnected = false;
        isConnecting = false;
      });
    }
    // Auto Reconnect retry
    reconnectTimer?.cancel();
    reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!isConnected) connectWebSocket();
    });
  }

  void _handleIncomingData(String packet) {
    if (packet.startsWith("SYNC:")) {
      String dataPart = packet.substring(5);
      List<String> items = dataPart.split(";");
      setState(() {
        for (String item in items) {
          List<String> kv = item.split("=");
          if (kv.length == 2) {
            _updateState(kv[0], kv[1]);
          }
        }
      });
    }
  }

  void _updateState(String key, String val) {
    switch (key) {
      case "VOL": masterVol = (double.tryParse(val) ?? masterVol).clamp(0, 29); break;
      case "SUB": subVol = (double.tryParse(val) ?? subVol).clamp(0, 29); break;
      case "BAS": bass = (double.tryParse(val) ?? bass).clamp(-15, 15); break;
      case "MID": mid = (double.tryParse(val) ?? mid).clamp(-15, 15); break;
      case "TRE": treble = (double.tryParse(val) ?? treble).clamp(-15, 15); break;
      case "GAIN": gain = (double.tryParse(val) ?? gain).clamp(0, 15); break;
      case "LOUD": loudness = (double.tryParse(val) ?? loudness).clamp(0, 15); break;
      case "INP": inputSource = val; break;
      case "SLP": sleepTimer = val; break;
      case "SUBCUT": subCutoff = val; break;
      case "BCTR": bassCenter = val; break;
      case "TRECUT": trebleCutoff = val; break;
    }
  }

  int lastSend = 0;
  void sendWsPacket(String key, dynamic value) {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastSend > 30 && channel != null && isConnected) {
      lastSend = now;
      channel!.sink.add("$key:$value");
    }
  }

  void _showIpDialog() {
    TextEditingController controller = TextEditingController(text: espIp);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131C2E),
        title: const Text("ESP32 IP Address", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "e.g. 192.168.43.100"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                espIp = controller.text.trim();
              });
              Navigator.pop(ctx);
              channel?.sink.close();
              connectWebSocket();
            },
            child: Text("CONNECT", style: TextStyle(color: accentColor)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Center(
              child: Text(
                "NV AUDIO DSP",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Theme Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(const Color(0xFF00E676)),
                _buildDot(const Color(0xFFFF4081)),
                _buildDot(const Color(0xFF00F2FE)),
                _buildDot(const Color(0xFFFF9100)),
              ],
            ),
            const SizedBox(height: 12),

            // Connection Status & IP Button
            GestureDetector(
              onTap: _showIpDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131C2E),
                  border: Border.all(color: const Color(0xFF1E2C45)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isConnected
                          ? "● CONNECTED (SYNCED)"
                          : (isConnecting ? "CONNECTING..." : "DISCONNECTED (TAP TO SET IP)"),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isConnected ? const Color(0xFF00E676) : (isConnecting ? Colors.amber : Colors.redAccent),
                      ),
                    ),
                    Text(espIp, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Card 1: Input Source
            _cardContainer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Input Source", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C273E),
                      side: const BorderSide(color: Color(0xFF1E2C45)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() => inputSource = inputSource == "BT AUDIO" ? "AUX IN" : "BT AUDIO");
                      sendWsPacket("INP", inputSource);
                    },
                    child: Text(inputSource, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 2: Sleep Timer
            _cardContainer(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Sleep Timer", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(sleepTimer, style: const TextStyle(color: Color(0xFF7D8B99), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ["OFF", "15m", "30m", "45m", "60m"].map((time) {
                      bool active = sleepTimer == time;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => sleepTimer = time);
                            sendWsPacket("SLP", time);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF1C273E) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: active ? const Color(0xFF1E2C45) : Colors.transparent),
                            ),
                            child: Text(time, style: TextStyle(color: active ? accentColor : const Color(0xFF7D8B99), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 3: Master & Subwoofer Volume
            _cardContainer(
              child: Column(
                children: [
                  _sliderBlock("Master Vol", masterVol, 0, 29, (val) {
                    setState(() => masterVol = val);
                    sendWsPacket("VOL", val.toInt());
                  }, unit: ""),
                  const Divider(color: Color(0xFF1E2C45), height: 24),
                  _sliderBlock("Subwoofer Vol", subVol, 0, 29, (val) {
                    setState(() => subVol = val);
                    sendWsPacket("SUB", val.toInt());
                  }, unit: ""),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 4: Tone Controls (-15 to +15 dB)
            _cardContainer(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => toneOpen = !toneOpen),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("TONE CONTROLS", style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 1.1)),
                        Icon(toneOpen ? Icons.arrow_drop_down : Icons.arrow_right, color: accentColor),
                      ],
                    ),
                  ),
                  if (toneOpen) ...[
                    const SizedBox(height: 14),
                    _sliderBlock("Bass", bass, -15, 15, (v) {
                      setState(() => bass = v);
                      sendWsPacket("BAS", v.toInt());
                    }, unit: "dB"),
                    const SizedBox(height: 12),
                    _sliderBlock("Mid", mid, -15, 15, (v) {
                      setState(() => mid = v);
                      sendWsPacket("MID", v.toInt());
                    }, unit: "dB"),
                    const SizedBox(height: 12),
                    _sliderBlock("Treble", treble, -15, 15, (v) {
                      setState(() => treble = v);
                      sendWsPacket("TRE", v.toInt());
                    }, unit: "dB"),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 5: Settings & Filters
            _cardContainer(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => filterOpen = !filterOpen),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("SETTINGS & FILTERS", style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 1.1)),
                        Icon(filterOpen ? Icons.arrow_drop_down : Icons.arrow_right, color: accentColor),
                      ],
                    ),
                  ),
                  if (filterOpen) ...[
                    const SizedBox(height: 14),
                    _sliderBlock("Gain", gain, 0, 15, (v) {
                      setState(() => gain = v);
                      sendWsPacket("GAIN", v.toInt());
                    }, unit: ""),
                    const SizedBox(height: 12),
                    _sliderBlock("Loudness", loudness, 0, 15, (v) {
                      setState(() => loudness = v);
                      sendWsPacket("LOUD", v.toInt());
                    }, unit: ""),
                    const SizedBox(height: 14),
                    _dropdownRow("Sub Cutoff", subCutoff, ["Flat", "80 Hz (Tight Bass)", "100 Hz", "120 Hz"], (v) {
                      setState(() => subCutoff = v!);
                      sendWsPacket("SUBCUT", v);
                    }),
                    _dropdownRow("Bass Center", bassCenter, ["60 Hz (Sub Bass)", "80 Hz", "100 Hz"], (v) {
                      setState(() => bassCenter = v!);
                      sendWsPacket("BCTR", v);
                    }),
                    _dropdownRow("Treble Cutoff", trebleCutoff, ["10.0 kHz", "12.5 kHz (Crisp)", "15.0 kHz"], (v) {
                      setState(() => trebleCutoff = v!);
                      sendWsPacket("TRECUT", v);
                    }),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(Color c) {
    bool active = accentColor == c;
    return GestureDetector(
      onTap: () => setState(() => accentColor = c),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: active ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2C45), width: 1.5),
      ),
      child: child,
    );
  }

  Widget _sliderBlock(String title, double val, double min, double max, ValueChanged<double> onChanged, {required String unit}) {
    String formattedVal = "${val > 0 && unit.isNotEmpty ? '+' : ''}${val.toInt()}$unit";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(formattedVal, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _stepBtn("-", () {
              if (val > min) onChanged(val - 1);
            }),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accentColor,
                  inactiveTrackColor: const Color(0xFF26354F),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(value: val, min: min, max: max, onChanged: onChanged),
              ),
            ),
            _stepBtn("+", () {
              if (val < max) onChanged(val + 1);
            }),
          ],
        )
      ],
    );
  }

  Widget _stepBtn(String sym, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1C273E),
          border: Border.all(color: const Color(0xFF1E2C45)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(sym, style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _dropdownRow(String title, String val, List<String> list, ValueChanged<String?> onChanged) {
    String selectedValue = list.contains(val) ? val : list.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          DropdownButton<String>(
            dropdownColor: const Color(0xFF131C2E),
            value: selectedValue,
            style: TextStyle(color: accentColor, fontSize: 12),
            underline: Container(),
            items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          )
        ],
      ),
    );
  }
}
