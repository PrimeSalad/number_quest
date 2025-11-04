import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart'; // ✅ for SystemNavigator.pop
import 'game_screen.dart';

void main() {
  runApp(const FingerAdditionApp());
}

class FingerAdditionApp extends StatefulWidget {
  const FingerAdditionApp({super.key});

  @override
  State<FingerAdditionApp> createState() => _FingerAdditionAppState();
}

class _FingerAdditionAppState extends State<FingerAdditionApp>
    with WidgetsBindingObserver {
  late final AudioPlayer _audioPlayer;
  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _initMusic();
  }

  Future<void> _initMusic() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setSource(AssetSource('music/bgm.mp3'));
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();
      print('✅ Background music playing...');
    } catch (e) {
      print('❌ Error playing background music: $e');
    }
  }

  void _toggleMute() async {
    setState(() {
      isMuted = !isMuted;
    });
    await _audioPlayer.setVolume(isMuted ? 0.0 : 1.0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audioPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finger Addition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.dynaPuffTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: MainMenuScreen(
        isMuted: isMuted,
        onToggleMute: _toggleMute,
      ),
      routes: {
        '/game': (_) => const GameScreen(),
      },
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  final bool isMuted;
  final VoidCallback onToggleMute;

  const MainMenuScreen({
    super.key,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  bool showHowToPlay = false;
  late AnimationController _popupAnimController;
  late Animation<double> _popupScaleAnim;

  @override
  void initState() {
    super.initState();
    _popupAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _popupScaleAnim = CurvedAnimation(
      parent: _popupAnimController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _popupAnimController.dispose();
    super.dispose();
  }

  Widget _woodButton({
    required String assetPath,
    required VoidCallback onTap,
    double width = 280,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 40),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonWidth = size.width * 0.6;

    return Scaffold(
      body: Stack(
        children: [
          /// 🌄 Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          /// 📋 Menu Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    Image.asset(
                      'assets/images/logo.png',
                      width: size.width * 0.7,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported, size: 100),
                    ),
                    const SizedBox(height: 36),

                    // ▶️ Start button
                    _woodButton(
                      assetPath: 'assets/images/start.png',
                      width: buttonWidth,
                      onTap: () {
                        Navigator.pushNamed(context, '/game');
                      },
                    ),
                    const SizedBox(height: 18),

                    // ❓ How to Play button
                    _woodButton(
                      assetPath: 'assets/images/htp.png',
                      width: buttonWidth,
                      onTap: () {
                        setState(() => showHowToPlay = true);
                        _popupAnimController.forward(from: 0);
                      },
                    ),
                    const SizedBox(height: 18),

                    // ❌ Quit button (✅ fixed)
                    _woodButton(
                      assetPath: 'assets/images/quit.png',
                      width: buttonWidth,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Quit'),
                            content: const Text('Do you want to exit the app?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop(); // close dialog
                                  SystemNavigator.pop(); // ✅ properly exit app
                                },
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          /// 🔇 Mute Button (top-right corner)
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(
                widget.isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: widget.onToggleMute,
            ),
          ),

          /// 🧠 HOW TO PLAY POPUP
          if (showHowToPlay)
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: ScaleTransition(
                    scale: _popupScaleAnim,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        /// Wooden frame image
                        Image.asset(
                          'assets/images/how.png',
                          width: 330,
                          fit: BoxFit.contain,
                        ),

                        /// X button (close)
                        Positioned(
                          top: 1,
                          right: 20,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => showHowToPlay = false);
                            },
                            child: Image.asset(
                              'assets/images/x.png',
                              height: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
