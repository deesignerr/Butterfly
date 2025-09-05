import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

void main() => runApp(MagicalButterflyGame());

class MagicalButterflyGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: GameScreen()),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late double butterflyX;
  late double butterflyY;
  double speed = 3.0;
  int score = 0;
  bool gameOver = false;

  double currentMultiplier = 1.0;
  bool multiplierActive = false;
  Timer? multiplierTimer;

  // Visual effect state
  Offset screenOffset = Offset.zero;
  bool flashActive = false;

  bool inBonusRound = false;
  bool showingBonusEndPopup = false;
  bool bonusPopupVisible = false;
  int bonusScore = 0;
  int displayedBonus = 0;

  int gemsCollected = 0;
  final int gemsRequired = 3;

  final Random random = Random();
  late AnimationController _controller;
  late double screenWidth;
  late double screenHeight;

  List<Obstacle> obstacles = [];
  List<FallingItem> items = [];
  List<BurstCoin> burstCoins = [];
  List<Particle> particles = [];
  List<FlowerPetal> petals = [];

  final List<String> obstacleTypes = ['🌸', '🍄', '🍃', '🐝'];

  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      screenWidth = MediaQuery.of(context).size.width;
      screenHeight = MediaQuery.of(context).size.height;
      butterflyX = screenWidth / 2 - 25;
      butterflyY = screenHeight - 100;
      initialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(seconds: 1000))
          ..addListener(_updateGame)
          ..repeat();
  }

  void _updateGame() {
    if (!initialized || gameOver) return;

    setState(() {
      // Increase speed gradually
      if (!inBonusRound && score != 0 && score % 10 == 0) {
        speed = 3.0 * (1 + 0.02 * (score ~/ 10));
      }
      speed = min(speed, 8.0);

      // Update obstacles
      if (!inBonusRound) {
        int baseObstacles = 1;
        int extraObstacles = (score ~/ 100) * 5;
        extraObstacles = min(extraObstacles, 50);
        int targetObstacles = baseObstacles + extraObstacles;

        while (obstacles.length < targetObstacles) {
          double lastY = obstacles.isNotEmpty ? obstacles.last.y : screenHeight;
          double spacing = 120;
          if (score >= 800) spacing = 30;
          if (score >= 900) spacing = 20;
          if (score >= 950) spacing = 10;

          if (obstacles.isEmpty || lastY > spacing) {
            obstacles.add(Obstacle(
              x: random.nextDouble() * (screenWidth - 50),
              y: -50,
              type: obstacleTypes[random.nextInt(obstacleTypes.length)],
              drift: random.nextDouble() * 1.5 - 0.75,
            ));
          } else {
            break;
          }
        }
      }

      // Update items
      if (!inBonusRound) {
        if (items.isEmpty || items.last.y > 80) {
          double roll = random.nextDouble();

          if (roll < 0.05) {
            items.add(FallingItem(
              x: random.nextDouble() * (screenWidth - 30),
              y: -30,
              type: FallingItemType.lightning,
              size: 40,
            ));
          } else if (score < 800 && roll < 0.10) {
            items.add(FallingItem(
              x: random.nextDouble() * (screenWidth - 40),
              y: -30,
              type: FallingItemType.gem,
              size: 30,
            ));
          } else if (roll < 0.15) {
            items.add(FallingItem(
              x: random.nextDouble() * (screenWidth - 30),
              y: -30,
              type: FallingItemType.magicOrb,
              size: 40,
            ));
          } else {
            items.add(FallingItem(
              x: random.nextDouble() * (screenWidth - 20),
              y: -30,
              type: FallingItemType.coin,
              size: 20,
            ));
          }
        }
      }

      // Move obstacles/items based on round
      obstacles = obstacles
          .map((o) => o.copyWith(
              y: o.y + speed,
              x: (o.x + o.drift).clamp(0.0, screenWidth - 50)))
          .toList();
      items = items
          .map((c) => c.copyWith(y: c.y + (inBonusRound ? speed * 2 : speed)))
          .toList();

      // Update particles, burstCoins, petals
      _updateEffectList(particles, 100, (p) => p.life > 0, (p) => p.copyWith(
          x: p.x + p.dx, y: p.y + p.dy, life: p.life - 1));
      _updateEffectList(burstCoins, 100, (b) => b.life > 0 && b.y <= screenHeight + 50,
          (b) => b.copyWith(dx: b.dx * 0.99, dy: b.dy + 0.25, x: b.x + b.dx, y: b.y + b.dy, life: b.life - 1));
      _updateEffectList(petals, 100, (p) => p.life > 0 && p.y <= screenHeight + 50,
          (p) => p.copyWith(x: p.x + p.dx, y: p.y + p.dy, life: p.life - 1));

      // Check collisions with items
      for (var item in items.toList()) {
        if (isColliding(
            butterflyX, butterflyY, 50, 50, item.x, item.y, item.size, item.size)) {
          switch (item.type) {
            case FallingItemType.coin:
            case FallingItemType.bill:
            case FallingItemType.moneyBag:
              if (!inBonusRound) {
                score += ((item.value ?? 1) * currentMultiplier).toInt();
              } else {
                bonusScore += ((item.value ?? 1) * currentMultiplier).toInt();
              }
              _spawnParticles(butterflyX + 25, butterflyY + 25, 6, Colors.yellowAccent);
              break;

            case FallingItemType.gem:
              _collectGem(item);
              break;

            case FallingItemType.magicOrb:
              if (!inBonusRound) {
                _triggerFlowerBurst();
                _spawnParticles(butterflyX + 25, butterflyY + 25, 12, Colors.pinkAccent);
              }
              break;

            case FallingItemType.lightning:
              _activateMultiplier(2.0, Duration(seconds: 10));
              _spawnMultiplierEffects(butterflyX + 25, butterflyY + 25);
              _triggerLightningEffects();
              break;

            default:
              break;
          }

          items.remove(item);
        }
      }

      // Check collisions with burstCoins
      for (var b in burstCoins.toList()) {
        if (isColliding(butterflyX, butterflyY, 50, 50, b.x, b.y, b.size, b.size)) {
          if (inBonusRound) bonusScore += b.value;
          else score += b.value;
          _spawnParticles(b.x, b.y, 4, Colors.yellowAccent);
          burstCoins.remove(b);
        }
      }

      // Check collisions with obstacles
      if (!inBonusRound) {
        for (var obs in obstacles.toList()) {
          if (isColliding(
              butterflyX, butterflyY, 50, 50, obs.x, obs.y, 50, 50)) {
            gameOver = true;
            _controller.stop();
            break;
          }
        }
      }

      // Remove off-screen items/obstacles
      obstacles.removeWhere((o) => o.y > screenHeight + 100);
      items.removeWhere((c) => c.y > screenHeight + 50);
    });
  }

  void _updateEffectList<T>(
      List<T> list, int maxLength, bool Function(T) isAlive, T Function(T) update) {
    for (var i = 0; i < list.length; i++) {
      list[i] = update(list[i]);
    }
    list.removeWhere((e) => !isAlive(e));
    if (list.length > maxLength) list.removeRange(0, list.length - maxLength);
  }

  void moveButterfly(DragUpdateDetails details) {
    setState(() {
      butterflyX = (butterflyX + details.delta.dx).clamp(0.0, screenWidth - 50);
    });
  }

  void _spawnParticles(double x, double y, int count, Color color) {
    for (int i = 0; i < count; i++) {
      particles.add(Particle(
        x: x,
        y: y,
        dx: random.nextDouble() * 6 - 3,
        dy: random.nextDouble() * -6,
        life: 18 + random.nextInt(20),
        color: color,
      ));
    }
  }

  void _triggerLightningEffects() {
    _triggerScreenShake();
    _triggerFlash();
    _spawnLightningBurst(butterflyX + 25, butterflyY + 25);
  }

  void _triggerScreenShake() {
    int ticks = 8;
    Timer.periodic(Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      if (ticks-- <= 0) {
        setState(() => screenOffset = Offset.zero);
        timer.cancel();
        return;
      }
      setState(() {
        screenOffset =
            Offset(random.nextDouble() * 8 - 4, random.nextDouble() * 8 - 4);
      });
    });
  }

  void _triggerFlash() {
    setState(() => flashActive = true);
    Timer(Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() => flashActive = false);
    });
  }

  void _spawnLightningBurst(double x, double y) {
    int sparkCount = 6;
    for (int i = 0; i < sparkCount; i++) {
      particles.add(Particle(
        x: x,
        y: y,
        dx: random.nextDouble() * 10 - 5,
        dy: random.nextDouble() * -10,
        life: 25 + random.nextInt(15),
        color: Colors.yellowAccent,
      ));
    }
  }

  void _triggerFlowerBurst() {
    int petalCount = ((12 + random.nextInt(8)) / 2).ceil();
    double originX = butterflyX + 25;
    double originY = butterflyY + 25;
    List<FlowerPetal> newPetals = [];

    for (int i = 0; i < petalCount; i++) {
      double angle = 2 * pi * i / petalCount + (random.nextDouble() - 0.5) * 0.2;
      double spd = 2.5 + random.nextDouble() * 2.5;
      newPetals.add(FlowerPetal(
        x: originX,
        y: originY,
        dx: cos(angle) * spd,
        dy: sin(angle) * spd,
        life: 40 + random.nextInt(30),
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        size: 18 + random.nextInt(14).toDouble(),
      ));
    }
    petals.addAll(newPetals);

    int ticks = 12 + random.nextInt(8);
    int coinsPerTick = 2 + random.nextInt(3);

    Timer.periodic(Duration(milliseconds: 110), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      List<FlowerPetal> snapPetals = petals.toList();
      if (snapPetals.isEmpty) return;
      for (int c = 0; c < coinsPerTick; c++) {
        FlowerPetal p = snapPetals[random.nextInt(snapPetals.length)];
        double spawnX = p.x + p.dx * 1.2 + random.nextDouble() * 8 - 4;
        double spawnY = p.y + p.dy * 1.2 + random.nextDouble() * 8 - 4;
        double vx = p.dx * 0.3 + random.nextDouble() * 2 - 1;
        double vy = p.dy * 0.2 - (1 + random.nextDouble() * 2);
        burstCoins.add(BurstCoin(
          x: spawnX,
          y: spawnY,
          dx: vx,
          dy: vy,
          life: 60,
          size: 18,
          value: 1,
        ));
      }
      if (timer.tick >= ticks) timer.cancel();
    });

    _spawnParticles(originX, originY, 18 + (petalCount ~/ 2), Colors.yellowAccent);
  }

  void _activateMultiplier(double multiplier, Duration duration) {
    multiplierTimer?.cancel();
    setState(() {
      currentMultiplier = multiplier;
      multiplierActive = true;
    });

    multiplierTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        currentMultiplier = 1.0;
        multiplierActive = false;
      });
    });
  }

  void _spawnMultiplierEffects(double x, double y) {
    int sparkCount = 6;
    for (int i = 0; i < sparkCount; i++) {
      particles.add(Particle(
        x: x,
        y: y,
        dx: random.nextDouble() * 6 - 3,
        dy: random.nextDouble() * -6,
        life: 20 + random.nextInt(20),
        color: Colors.yellowAccent.withOpacity(0.8),
      ));
    }
  }

  void _collectGem(FallingItem gem) {
    setState(() {
      gemsCollected++;
    });

    double targetX = 200 + 40.0 * (gemsCollected - 1);
    double targetY = 40.0;

    double dx = (targetX - gem.x) / 15;
    double dy = (targetY - gem.y) / 15;

    int life = 15;
    for (int i = 0; i < life; i++) {
      Timer(Duration(milliseconds: i * 16), () {
        if (!mounted) return;
        setState(() {
          burstCoins.add(BurstCoin(
            x: gem.x + dx * i,
            y: gem.y + dy * i,
            dx: 0,
            dy: 0,
            life: 1,
            size: 24,
            value: 0,
          ));
        });
      });
    }

    if (gemsCollected >= gemsRequired) {
      Future.delayed(Duration(milliseconds: 250), () {
        _triggerBonusRound();
        setState(() {
          gemsCollected = 0;
        });
      });
    }
  }

  void _triggerBonusRound() {
    if (inBonusRound) return;
    setState(() {
      inBonusRound = true;
      bonusPopupVisible = true;
      bonusScore = 0;
      items.clear();
      obstacles.clear();
    });

    Future.delayed(Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        bonusPopupVisible = false;
      });

      int bonusDurationMs = 5000;
      int spawnIntervalMs = 100;
      int ticks = bonusDurationMs ~/ spawnIntervalMs;

      Timer.periodic(Duration(milliseconds: spawnIntervalMs), (timer) {
        if (!mounted) return;
        if (timer.tick >= ticks) {
          timer.cancel();
          _endBonusRound();
          return;
        }

        double xPos = random.nextDouble() * (screenWidth - 40);
        double yPos = -30;
        int roll = random.nextInt(3);
        FallingItemType type;
        int value;
        switch (roll) {
          case 0:
            type = FallingItemType.coin;
            value = 1 + random.nextInt(3);
            break;
          case 1:
            type = FallingItemType.bill;
            value = 5 + random.nextInt(6);
            break;
          default:
            type = FallingItemType.moneyBag;
            value = 10 + random.nextInt(11);
            break;
        }

        items.add(FallingItem(
          x: xPos,
          y: yPos,
          type: type,
          size: 28 + random.nextInt(9).toDouble(),
          value: value,
        ));
      });
    });
  }

  void _endBonusRound() {
    setState(() {
      items.clear();
      obstacles.clear();
      showingBonusEndPopup = true;
      displayedBonus = 0;
    });

    int increment = (bonusScore / 50).ceil();

    Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (!mounted) return;

      if (displayedBonus >= bonusScore) {
        timer.cancel();
        Future.delayed(Duration(milliseconds: 500), () {
          _animateBonusIntoScore();
        });
        return;
      }

      setState(() {
        displayedBonus = (displayedBonus + increment).clamp(0, bonusScore);
      });
    });
  }

  void _animateBonusIntoScore() {
    int remaining = bonusScore;
    int step = (bonusScore / 50).ceil();

    Timer.periodic(Duration(milliseconds: 20), (timer) {
      if (!mounted) return;

      if (remaining <= 0) {
        timer.cancel();
        Future.delayed(Duration(milliseconds: 1500), () {
          if (!mounted) return;
          setState(() {
            showingBonusEndPopup = false;
            bonusScore = 0;
            inBonusRound = false;
          });
        });
        return;
      }

      setState(() {
        int actualStep = min(step, remaining);
        if (score + actualStep > 950) {
          actualStep = 950 - score;
          remaining = 0;
        }

        remaining -= actualStep;
        score += actualStep;
      });
    });
  }

  void restartGame() {
    setState(() {
      obstacles.clear();
      items.clear();
      burstCoins.clear();
      particles.clear();
      petals.clear();
      score = 0;
      speed = 3.0;
      gameOver = false;
      butterflyX = screenWidth / 2 - 25;
      _controller.repeat();
    });
  }

  bool isColliding(double bx, double by, double bw, double bh, double ox,
      double oy, double ow, double oh) {
    return bx < ox + ow && bx + bw > ox && by < oy + oh && by + bh > oy;
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return Container();

    return GestureDetector(
      onHorizontalDragUpdate: moveButterfly,
      onTap: () {
        if (gameOver) restartGame();
      },
      child: Transform.translate(
        offset: screenOffset,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.lightBlue.shade200, Colors.pink.shade100],
            ),
          ),
          child: Stack(
            children: [
              if (flashActive)
                Positioned.fill(
                  child: Container(color: Colors.yellow.withOpacity(0.3)),
                ),
              for (var p in petals)
                Positioned(
                  left: p.x,
                  top: p.y,
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      color: p.color.withOpacity((p.life / 70).clamp(0.0, 1.0)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              for (var b in burstCoins)
                Positioned(
                  left: b.x,
                  top: b.y,
                  child: Text('🪙', style: TextStyle(fontSize: b.size)),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: ParticlePainter(particles),
                ),
              ),
              for (var item in items)
                Positioned(
                  left: item.x,
                  top: item.y,
                  child: item.type == FallingItemType.coin
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Text('🪙', style: TextStyle(fontSize: item.size)),
                            if (multiplierActive)
                              Positioned(
                                right: -25,
                                top: -5,
                                child: Text(
                                  'x${currentMultiplier.toInt()}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.yellowAccent,
                                    shadows: [
                                      Shadow(color: Colors.white, blurRadius: 6),
                                      Shadow(color: Colors.orangeAccent, blurRadius: 8),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          item.type == FallingItemType.magicOrb
                              ? '✨'
                              : item.type == FallingItemType.gem
                                  ? '💎'
                                  : item.type == FallingItemType.bill
                                      ? '💵'
                                      : item.type == FallingItemType.lightning
                                          ? '⚡'
                                          : '💰',
                          style: TextStyle(fontSize: item.size),
                        ),
                ),
              for (var obs in obstacles)
                Positioned(
                  left: obs.x,
                  top: obs.y,
                  child: Text(obs.type, style: TextStyle(fontSize: 50)),
                ),
              // Butterfly (no glow)
              Positioned(
                left: butterflyX,
                top: butterflyY,
                child: Text('🦋', style: TextStyle(fontSize: 50)),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: Text(
                  'Coins: $score',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                  ),
                ),
              ),
              Positioned(
                top: 90,
                left: 20,
                child: Row(
                  children: List.generate(gemsRequired, (index) {
                    bool filled = index < gemsCollected;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        Icons.diamond,
                        color: filled ? Colors.blueAccent : Colors.white54,
                        size: 32,
                      ),
                    );
                  }),
                ),
              ),
              if (bonusPopupVisible)
                Center(
                  child: Container(
                    color: Colors.black87,
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'BONUS ROUND!',
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.yellowAccent,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                      ),
                    ),
                  ),
                ),
              if (showingBonusEndPopup)
                Center(
                  child: Container(
                    color: Colors.black87,
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'BONUS SCORE: $displayedBonus',
                      style: TextStyle(
                        fontSize: 42,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                      ),
                    ),
                  ),
                ),
              if (gameOver)
                Center(
                  child: Container(
                    color: Colors.black54,
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'GAME OVER\nTap to Restart',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ParticlePainter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    for (var p in particles) {
      paint.color = p.color.withOpacity((p.life / 40).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -------------------- Supporting Classes --------------------

class Obstacle {
  final double x;
  final double y;
  final String type;
  final double drift;

  Obstacle({required this.x, required this.y, required this.type, this.drift = 0.0});

  Obstacle copyWith({double? x, double? y, String? type, double? drift}) {
    return Obstacle(
      x: x ?? this.x,
      y: y ?? this.y,
      type: type ?? this.type,
      drift: drift ?? this.drift,
    );
  }
}

class FallingItem {
  final double x;
  final double y;
  final FallingItemType type;
  final double size;
  final double dx;
  final int? value;

  FallingItem({required this.x, required this.y, required this.type, this.size = 20, this.dx = 0, this.value});

  FallingItem copyWith({double? x, double? y}) {
    return FallingItem(
      x: x ?? this.x,
      y: y ?? this.y,
      type: type,
      size: size,
      dx: dx,
      value: value,
    );
  }
}

enum FallingItemType { coin, magicOrb, gem, star, bill, moneyBag, lightning }

class BurstCoin {
  final double x, y, dx, dy;
  final int life;
  final double size;
  final int value;

  BurstCoin({required this.x, required this.y, required this.dx, required this.dy, required this.life, required this.size, required this.value});

  BurstCoin copyWith({double? x, double? y, double? dx, double? dy, int? life, double? size, int? value}) {
    return BurstCoin(
      x: x ?? this.x,
      y: y ?? this.y,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      life: life ?? this.life,
      size: size ?? this.size,
      value: value ?? this.value,
    );
  }
}

class Particle {
  final double x, y, dx, dy;
  final int life;
  final Color color;

  Particle({required this.x, required this.y, required this.dx, required this.dy, required this.life, required this.color});

  Particle copyWith({double? x, double? y, double? dx, double? dy, int? life, Color? color}) {
    return Particle(
      x: x ?? this.x,
      y: y ?? this.y,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      life: life ?? this.life,
      color: color ?? this.color,
    );
  }
}

class FlowerPetal {
  final double x, y, dx, dy;
  final int life;
  final Color color;
  final double size;

  FlowerPetal({required this.x, required this.y, required this.dx, required this.dy, required this.life, required this.color, required this.size});

  FlowerPetal copyWith({double? x, double? y, double? dx, double? dy, int? life, Color? color, double? size}) {
    return FlowerPetal(
      x: x ?? this.x,
      y: y ?? this.y,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      life: life ?? this.life,
      color: color ?? this.color,
      size: size ?? this.size,
    );
  }
}
