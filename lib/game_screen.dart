// game_screen.dart
// Now includes 3 rounds before showing overlay. Optimized and stable.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<int?> gridValues;
  late List<int> draggableNumbers;
  late List<GlobalKey<_ShakeSlotState>> shakeKeys;

  int score = 0;
  bool showOverlay = false;
  bool showMenuPopup = false;
  bool showHowToPlay = false;

  int round = 1;
  static const int maxRounds = 3;

  final Random random = Random();
  late ConfettiController _confettiController;
  late AnimationController _menuAnimController;
  late Animation<double> _menuScaleAnim;

  late List<int> missingNumbers;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 900));
    _menuAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _menuScaleAnim = CurvedAnimation(parent: _menuAnimController, curve: Curves.easeOutBack);
    _initGame();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _menuAnimController.dispose();
    super.dispose();
  }

  void _initGame({int blankCount = 8}) {
    gridValues = List<int?>.generate(20, (i) => i + 1);
    final indices = List<int>.generate(20, (i) => i)..shuffle(random);
    final blanks = indices.take(blankCount).toSet();
    for (int i = 0; i < 20; i++) {
      if (blanks.contains(i)) gridValues[i] = null;
    }
    missingNumbers = blanks.map((i) => i + 1).toList();

    draggableNumbers = <int>[];
    _refillDraggables();

    shakeKeys = List.generate(20, (_) => GlobalKey<_ShakeSlotState>());

    setState(() {
      showOverlay = false;
      showMenuPopup = false;
      showHowToPlay = false;
    });
  }

  void _refillDraggables() {
    final visible = gridValues.whereType<int>().toSet();
    final pool = List<int>.generate(20, (i) => i + 1).where((n) => !visible.contains(n)).toList();
    final missingPool = missingNumbers.where((n) => !draggableNumbers.contains(n)).toList();
    final distractorPool = pool.where((n) => !missingPool.contains(n) && !draggableNumbers.contains(n)).toList();

    while (draggableNumbers.length < 4 && missingPool.isNotEmpty) {
      draggableNumbers.add(missingPool.removeAt(random.nextInt(missingPool.length)));
    }
    while (draggableNumbers.length < 4 && distractorPool.isNotEmpty) {
      draggableNumbers.add(distractorPool.removeAt(random.nextInt(distractorPool.length)));
    }

    final fallbackPool = List<int>.generate(20, (i) => i + 1)
        .where((n) => !draggableNumbers.contains(n) && !visible.contains(n))
        .toList();
    while (draggableNumbers.length < 4 && fallbackPool.isNotEmpty) {
      draggableNumbers.add(fallbackPool.removeAt(random.nextInt(fallbackPool.length)));
    }

    draggableNumbers.shuffle(random);
    setState(() {});
  }

  void _onNumberDropped(int number, int slotIndex) {
    final expected = slotIndex + 1;
    if (number == expected) {
      setState(() {
        gridValues[slotIndex] = number;
        score += 10;
        draggableNumbers.remove(number);
        missingNumbers.remove(number);
      });
      _confettiController.play();
      _refillDraggables();

      if (!gridValues.contains(null)) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          if (round < maxRounds) {
            setState(() {
              round++;
            });
            _initGame(blankCount: 8 + round); // harder each round
          } else {
            setState(() => showOverlay = true);
          }
        });
      }
    } else {
      shakeKeys[slotIndex].currentState?.shake();
      setState(() => score = max(0, score - 5));
    }
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      itemCount: 20,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final val = gridValues[index];
        return Center(
          child: ShakeSlot(
            key: shakeKeys[index],
            child: DragTarget<int>(
              onWillAccept: (data) => gridValues[index] == null,
              onAccept: (data) => _onNumberDropped(data, index),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  child: val == null
                      ? Image.asset('assets/images/blank.png')
                      : Image.asset('assets/images/$val.png'),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggables() {
    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: draggableNumbers.map((n) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Draggable<int>(
              data: n,
              feedback: Material(
                color: Colors.transparent,
                child: Image.asset('assets/images/$n.png', height: 64),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: Image.asset('assets/images/$n.png', height: 64),
              ),
              child: Image.asset('assets/images/$n.png', height: 64),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEndOverlay() => AnimatedOpacity(
    opacity: showOverlay ? 1 : 0,
    duration: const Duration(milliseconds: 300),
    child: Visibility(
      visible: showOverlay,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset("assets/images/complete.png", height: 450, width: 350),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 220),
                  Text(
                    "Score: $score",
                    style: GoogleFonts.dynaPuff(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Rounds Completed: $round / $maxRounds",
                    style: GoogleFonts.dynaPuff(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Image.asset("assets/images/home.png", height: 60),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            score = 0;
                            round = 1;
                          });
                          _initGame();
                        },
                        child: Image.asset("assets/images/restart.png", height: 60),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/bg2.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Image.asset("assets/images/scoreplaceholder.png", height: 60),
                            Padding(
                              padding: const EdgeInsets.only(right: 28),
                              child: Text(
                                "Score: $score",
                                style: GoogleFonts.dynaPuff(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() => showMenuPopup = true);
                            _menuAnimController.forward(from: 0);
                          },
                          child: Image.asset("assets/images/menu.png", height: 50),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "Number Fill",
                    style: GoogleFonts.dynaPuff(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                    child: Text(
                      "Complete all 3 rounds by filling in the missing numbers!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dynaPuff(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        Expanded(child: _buildGrid()),
                        const SizedBox(height: 8),
                        Container(
                          height: 100,
                          width: 350,
                          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage("assets/images/wood.png"),
                              fit: BoxFit.fill,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _buildDraggables(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 25,
              gravity: 0.4,
            ),
          ),
          if (showOverlay) _buildEndOverlay(),
        ],
      ),
    );
  }
}

class ShakeSlot extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;
  const ShakeSlot({super.key, required this.child, this.duration = const Duration(milliseconds: 420), this.offset = 12.0});
  @override
  State<ShakeSlot> createState() => _ShakeSlotState();
}

class _ShakeSlotState extends State<ShakeSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.elasticIn);
  }

  void shake() => _controller.forward(from: 0.0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _shakeTransform(double progress) {
    final freq = 6;
    final decay = 1 - progress;
    return sin(progress * pi * freq) * widget.offset * decay;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final dx = _shakeTransform(_anim.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}