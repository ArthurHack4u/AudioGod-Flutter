import 'dart:ui'; 
import 'dart:io'; 
import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:just_audio/just_audio.dart'; 
import 'package:file_picker/file_picker.dart'; 

class AudioBrain extends ChangeNotifier {
  static final AudioBrain _instance = AudioBrain._internal();
  factory AudioBrain() => _instance;
  AudioBrain._internal();

  static const platform = MethodChannel('com.moran.audio_god_eq/audio');

  final AudioPlayer _androidPlayer = AudioPlayer();

  String songTitle = "Esperando Audio...";
  String artistName = "Sistema Listo";
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  bool isLoading = false;
  
  String outputDeviceName = "Escaneando...";
  Timer? _deviceTimer;

  List<double> eqBands = [0.5, 0.5, 0.5, 0.5, 0.5];
  String currentPreset = "Manual";

  void init() {
    _startDeviceScanner();

    if (Platform.isAndroid) {
      _androidPlayer.playerStateStream.listen((state) {
        isPlaying = state.playing;
        if (state.playing) _activarAndroidEQ(_androidPlayer.androidAudioSessionId ?? 0); 
        notifyListeners();
      });
      _androidPlayer.positionStream.listen((p) { position = p; notifyListeners(); });
      _androidPlayer.durationStream.listen((d) { duration = d ?? Duration.zero; notifyListeners(); });
    }
  }

  void _startDeviceScanner() {
    _deviceTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final String name = await platform.invokeMethod('getDeviceName');
        if (name != outputDeviceName) {
          outputDeviceName = name;
          notifyListeners();
        }
      } catch (e) { print(e); }
    });
  }

  Future<void> activarModoSpotify() async {
    if (!Platform.isAndroid) return;
    try {
      await platform.invokeMethod('activarEQ', {"sessionId": 0});
      for(int i=0; i<5; i++) _sendToAndroid(i, eqBands[i]);
      
      songTitle = "Audio Externo";
      artistName = "Modo Global (Spotify/YT)";
      notifyListeners();
    } catch (e) { print("Error Global: $e"); }
  }

  Future<void> pickSong(BuildContext context) async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'aac'],
      );

      if (result != null) {
        String path = result.files.single.path!;
        songTitle = result.files.single.name.replaceAll(RegExp(r'\.(mp3|wav|m4a|flac|aac)'), '');
        
        if (Platform.isIOS) {
          await platform.invokeMethod('playNativeIOS', {"path": path});
          isPlaying = true;
          for(int i=0; i<5; i++) updateBand(i, eqBands[i]);
        } else {
          await _androidPlayer.setFilePath(path);
          _androidPlayer.play();
        }
        artistName = "Reproducción Local";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void togglePlay() async {
    if (Platform.isIOS) {
      bool playing = await platform.invokeMethod('pauseNativeIOS');
      isPlaying = playing;
    } else {
      if (isPlaying) _androidPlayer.pause(); else _androidPlayer.play();
    }
    notifyListeners();
  }

  void seek(double seconds) {
    if (Platform.isAndroid) _androidPlayer.seek(Duration(seconds: seconds.toInt()));
  }

  void updateBand(int index, double value) {
    eqBands[index] = value;
    currentPreset = "Personalizado";
    notifyListeners();
    if (Platform.isIOS) {
      platform.invokeMethod('updateEqIOS', {"band": index, "gain": value});
    } else {
      _sendToAndroid(index, value);
    }
  }

  void applyPreset(String name) {
    currentPreset = name;
    switch (name) {
      case "Bass Boost": eqBands = [0.9, 0.8, 0.6, 0.4, 0.3]; break;
      case "Vocal / Podcast": eqBands = [0.3, 0.4, 0.8, 0.7, 0.4]; break;
      case "Treble / Gaming": eqBands = [0.4, 0.4, 0.5, 0.8, 0.9]; break;
      case "Flat / Monitor": eqBands = [0.5, 0.5, 0.5, 0.5, 0.5]; break;
      case "V-Shape (KZ)": eqBands = [0.85, 0.4, 0.3, 0.4, 0.85]; break;
    }
    notifyListeners();
    for (int i = 0; i < 5; i++) {
      if (Platform.isIOS) platform.invokeMethod('updateEqIOS', {"band": i, "gain": eqBands[i]});
      else _sendToAndroid(i, eqBands[i]);
    }
  }

  Future<void> _activarAndroidEQ(int id) async {
    try { 
      await platform.invokeMethod('activarEQ', {"sessionId": id}); 
      for(int i=0; i<5; i++) _sendToAndroid(i, eqBands[i]);
    } catch (e) { print(e); }
  }

  void _sendToAndroid(int band, double val) {
    int nativeLevel = ((val - 0.5) * 3000).toInt();
    try { platform.invokeMethod('setBandLevel', {"band": band, "level": nativeLevel}); } catch (e) {}
  }
}

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  AudioBrain().init();
  runApp(const AudioGodApp());
}

class AudioGodApp extends StatelessWidget {
  const AudioGodApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio God IO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: Colors.cyanAccent,
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.cyanAccent,
          inactiveTrackColor: Colors.white10,
          thumbColor: Colors.white,
          trackHeight: 4.0,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        ),
      ),
      home: const MainLayout(),
    );
  }
}

class GlassBox extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blur;
  const GlassBox({super.key, required this.child, this.opacity = 0.1, this.blur = 10});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            gradient: LinearGradient(colors: [Colors.white.withOpacity(opacity + 0.05), Colors.white.withOpacity(opacity)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: child,
        ),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 2; 

  void _showStudentInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          height: 280,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.groups_3, size: 50, color: Colors.cyanAccent),
              SizedBox(height: 15),
              Text("EQUIPO DE DESARROLLO", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2)),
              SizedBox(height: 20),
              
              Text("Moran Escalante\nBryan Arturo", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Matrícula: 67406", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              
              SizedBox(height: 15),
              Divider(color: Colors.white24, indent: 20, endIndent: 20),
              SizedBox(height: 15),

              Text("Rafael Inurreta\ndel Valle", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Matrícula: 62151", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0: return const HomeScreen();
      case 1: return const EqualizerScreen();
      case 2: return const PlayerScreen();
      case 3: return const PresetsScreen();
      default: return const PlayerScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioBrain(),
      builder: (context, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364), Colors.black]),
            ),
            child: Stack(
              children: [
                Positioned(top: -50, right: -50, child: _glowBall(Colors.purpleAccent)),
                Positioned(bottom: 150, left: -30, child: _glowBall(Colors.cyanAccent)),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("AUDIO GOD", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                            GestureDetector(
                              onTap: _showStudentInfo,
                              child: GlassBox(opacity: 0.2, child: Container(padding: const EdgeInsets.all(8), child: const Icon(Icons.headphones, size: 20, color: Colors.cyanAccent))),
                            ),
                          ],
                        ),
                      ),
                      if (_currentIndex != 3)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text("PRESET: ${AudioBrain().currentPreset.toUpperCase()}", style: const TextStyle(fontSize: 10, color: Colors.cyanAccent)),
                        ),
                      Expanded(child: _getCurrentScreen()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: GlassBox(
              opacity: 0.15, blur: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(Icons.grid_view, 0),
                    _navItem(Icons.graphic_eq, 1),
                    _navItem(Icons.play_circle_fill, 2),
                    _navItem(Icons.tune, 3),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(IconData icon, int index) {
    bool isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.white38, size: 28),
      onPressed: () => setState(() => _currentIndex = index),
    );
  }

  Widget _glowBall(Color color) {
    return Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.25)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: Container(color: Colors.transparent)));
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioBrain(),
      builder: (context, child) {
        String deviceName = AudioBrain().outputDeviceName;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ESTADO DEL SISTEMA", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 1.5)),
              const SizedBox(height: 15),
              GlassBox(
                child: ListTile(
                  leading: Icon(
                    deviceName.contains("Bluetooth") ? Icons.bluetooth_audio : 
                    deviceName.contains("USB") || deviceName.contains("DAC") ? Icons.usb : Icons.speaker,
                    color: Colors.white, size: 30
                  ),
                  title: Text(deviceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(Platform.isAndroid ? "Motor Híbrido Android" : "Motor iOS Native Swift", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: const Icon(Icons.check_circle, color: Colors.greenAccent),
                ),
              ),
              const SizedBox(height: 20),
              
              if (Platform.isAndroid)
                GestureDetector(
                  onTap: () async {
                    await AudioBrain().activarModoSpotify();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚡ Modo Global Activado: Prueba en Spotify"), backgroundColor: Colors.green));
                  },
                  child: GlassBox(opacity: 0.2, child: Container(padding: const EdgeInsets.all(15), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.layers, color: Colors.greenAccent), SizedBox(width: 10), Text("ACTIVAR MODO SPOTIFY", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))]))),
                ),
              
              const SizedBox(height: 30),
              const Text("MONITOREO DE SALIDA", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 1.5)),
              const SizedBox(height: 15),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.4,
                  children: const [
                    _Stat("Engine", "Activo", Icons.settings_system_daydream),
                    _Stat("Sample Rate", "48 kHz", Icons.waves),
                    _Stat("Bit Depth", "16-bit", Icons.graphic_eq),
                    _Stat("Latencia", "Low", Icons.speed),
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }
}
class _Stat extends StatelessWidget {
  final String t, v; final IconData i;
  const _Stat(this.t, this.v, this.i);
  @override
  Widget build(BuildContext context) => GlassBox(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: Colors.white38), const SizedBox(height: 5), Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10))]));
}

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioBrain(),
      builder: (context, child) {
        final brain = AudioBrain();
        final freqs = ["60Hz", "250Hz", "1K", "4K", "16K"];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Spacer(),
              SizedBox(height: 400, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(5, (index) {
                return Column(children: [
                  Text("+${((brain.eqBands[index] - 0.5) * 30).toInt()}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                  const SizedBox(height: 10),
                  Expanded(child: GlassBox(opacity: 0.05, child: RotatedBox(quarterTurns: 3, child: Slider(value: brain.eqBands[index], min: 0.0, max: 1.0, onChanged: (v) => brain.updateBand(index, v))))),
                  const SizedBox(height: 15),
                  Text(freqs[index], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                ]);
              }))),
              const Spacer(),
              TextButton.icon(onPressed: () => brain.applyPreset("Flat / Monitor"), icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 18), label: const Text("RESET", style: TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});
  String _fmt(Duration d) => "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioBrain(),
      builder: (context, child) {
        final brain = AudioBrain();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassBox(child: Container(height: 260, width: 260, alignment: Alignment.center, child: Icon(Icons.album, size: 120, color: brain.isPlaying ? Colors.cyanAccent : Colors.white12))),
              const SizedBox(height: 40),
              Text(brain.songTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              const SizedBox(height: 5),
              Text(brain.artistName, style: const TextStyle(fontSize: 14, color: Colors.cyanAccent)),
              const SizedBox(height: 30),
              Slider(min: 0, max: brain.duration.inSeconds.toDouble(), value: brain.position.inSeconds.toDouble().clamp(0, brain.duration.inSeconds.toDouble()), onChanged: (v) => brain.seek(v)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(brain.position), style: const TextStyle(color: Colors.white54, fontSize: 12)), Text(_fmt(brain.duration), style: const TextStyle(color: Colors.white54, fontSize: 12))]),
              const SizedBox(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                brain.isLoading ? const SizedBox(width:30, height:30, child: CircularProgressIndicator(color: Colors.cyanAccent)) : IconButton(onPressed: () => brain.pickSong(context), icon: const Icon(Icons.folder_open_rounded, color: Colors.white70, size: 35)),
                GestureDetector(onTap: brain.togglePlay, child: GlassBox(opacity: 0.3, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: brain.isPlaying ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20)] : []), child: Icon(brain.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 50)))),
                const IconButton(onPressed: null, icon: Icon(Icons.settings, color: Colors.white24, size: 35)),
              ])
            ],
          ),
        );
      }
    );
  }
}

class PresetsScreen extends StatelessWidget {
  const PresetsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioBrain(),
      builder: (context, child) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("PERFILES", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 15),
            _PresetBtn("Bass Boost", "Explosión de sub-bajos", Icons.speaker),
            _PresetBtn("V-Shape (KZ)", "Clásico sonido Chi-Fi", Icons.headphones),
            _PresetBtn("Vocal / Podcast", "Claridad en voces", Icons.mic),
            _PresetBtn("Treble / Gaming", "Pasos y detalles", Icons.gamepad),
            _PresetBtn("Flat / Monitor", "Sonido puro", Icons.graphic_eq),
          ],
        );
      }
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final String name, desc; final IconData icon;
  const _PresetBtn(this.name, this.desc, this.icon);
  @override
  Widget build(BuildContext context) {
    final isActive = AudioBrain().currentPreset == name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => AudioBrain().applyPreset(name),
        child: GlassBox(opacity: isActive ? 0.25 : 0.05, child: ListTile(leading: Icon(icon, color: isActive ? Colors.cyanAccent : Colors.white), title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.cyanAccent : Colors.white)), subtitle: Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)), trailing: isActive ? const Icon(Icons.check_circle, color: Colors.cyanAccent) : null)),
      ),
    );
  }
}