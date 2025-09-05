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
  List<StaticParticle> particles = [];

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

      // Spawn obstacles
      int targetObstacles = 1 + min(score ~/ 100 * 5, 50);
      while (obstacles.length < targetObstacles) {
        double lastY = obstacles.isNotEmpty ? obstacles.last.y : screenHeight;
        double spacing = 120;
        if (score >= 800) spacing = 30;
        if (obstacles.isEmpty || lastY > spacing) {
          obstacles.add(Obstacle(
              x: random.nextDouble() * (screenWidth - 50),
              y: -50,
              type: obstacleTypes[random.nextInt(obstacleTypes.length)],
              drift: random.nextDouble() * 1.5 - 0.75));
        } else {
          break;
        }
      }

      // Spawn items
      if (items.isEmpty || items.last.y > 80) {
        double roll = random.nextDouble();
        FallingItemType type;
        int value = 1;
        double size = 20;
        if (roll < 0.05) {
          type = FallingItemType.lightning;
          size = 40;
        } else if (score < 800 && roll < 0.10) {
          type = FallingItemType.gem;
          size = 30;
        } else if (roll < 0.15) {
          type = FallingItemType.magicOrb;
          size = 30;
        } else {
          type = FallingItemType.coin;
          size = 20;
        }
        items.add(FallingItem(
            x: random.nextDouble() * (screenWidth - size),
            y: -30,
            type: type,
            size: size,
            value: value));
      }

      // Move obstacles & items
      obstacles = obstacles
          .map((o) => o.copyWith(
              y: o.y + speed, x: (o.x + o.drift).clamp(0.0, screenWidth - 50)))
          .toList();
      items = items
          .map((c) => c.copyWith(y: c.y + (inBonusRound ? speed * 2 : speed)))
          .toList();

      // Move burstCoins
      for (var i = 0; i < burstCoins.length; i++) {
        BurstCoin b = burstCoins[i];
        burstCoins[i] = b.copyWith(y: b.y + b.dy);
      }
      burstCoins.removeWhere((b) => b.y > screenHeight + 50);

      // Move particles
      for (var i = 0; i < particles.length; i++) {
        StaticParticle p = particles[i];
        particles[i] = p.copyWith(y: p.y + 0.5);
      }
      particles.removeWhere((p) => p.y > screenHeight + 50);

      // Check collisions
      for (var item in items.toList()) {
        if (_isColliding(butterflyX, butterflyY, 50, 50, item.x, item.y, item.size, item.size)) {
          switch (item.type) {
            case FallingItemType.coin:
            case FallingItemType.bill:
            case FallingItemType.moneyBag:
              _collectScore(item.value!);
              break;
            case FallingItemType.gem:
              _collectGem(item);
              break;
            case FallingItemType.magicOrb:
              _triggerMagicOrb();
              break;
            case FallingItemType.lightning:
              _activateMultiplier(2.0, Duration(seconds: 10));
              break;
            default:
              break;
          }
          items.remove(item);
        }
      }

      // Check collisions with obstacles
      if (!inBonusRound) {
        for (var obs in obstacles.toList()) {
          if (_isColliding(
              butterflyX, butterflyY, 50, 50, obs.x, obs.y, 50, 50)) {
            gameOver = true;
            _controller.stop();
            break;
          }
        }
      }

      obstacles.removeWhere((o) => o.y > screenHeight + 100);
      items.removeWhere((c) => c.y > screenHeight + 50);
    });
  }

  void moveButterfly(DragUpdateDetails details) {
    setState(() {
      butterflyX = (butterflyX + details.delta.dx).clamp(0.0, screenWidth - 50);
    });
  }

  void _collectScore(int value) {
    score += (value * currentMultiplier).toInt();
    particles.add(StaticParticle(
      x: butterflyX + 25,
      y: butterflyY + 25,
      size: 5,
      color: Colors.yellowAccent,
    ));
  }

  void _triggerMagicOrb() {
    // spawn 3 small coins directly above butterfly
    int coinCount = 3;
    for (int i = 0; i < coinCount; i++) {
      burstCoins.add(BurstCoin(
        x: butterflyX + random.nextDouble() * 30,
        y: butterflyY - 10 - i * 5,
        dx: 0,
        dy: 2 + random.nextDouble() * 1,
        life: 100,
        size: 20,
        value: 1,
      ));
    }

    // spawn tiny static particles
    for (int i = 0; i < 5; i++) {
      particles.add(StaticParticle(
        x: butterflyX + random.nextDouble() * 40,
        y: butterflyY + random.nextDouble() * 10,
        size: 4,
        color: Colors.pinkAccent,
      ));
    }
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

  void _collectGem(FallingItem gem) {
    gemsCollected++;
    burstCoins.add(BurstCoin(
      x: gem.x,
      y: gem.y,
      dx: 0,
      dy: 2,
      life: 50,
      size: 20,
      value: 0,
    ));
    if (gemsCollected >= gemsRequired) {
      gemsCollected = 0;
      _triggerBonusRound();
    }
  }

  void _triggerBonusRound() {
    inBonusRound = true;
    bonusPopupVisible = true;
    bonusScore = 0;
    items.clear();
    obstacles.clear();
    Future.delayed(Duration(milliseconds: 500), () {
      bonusPopupVisible = false;
      int bonusDurationMs = 5000;
      int spawnIntervalMs = 100;
      int ticks = bonusDurationMs ~/ spawnIntervalMs;
      Timer.periodic(Duration(milliseconds: spawnIntervalMs), (timer) {
        if (!mounted) return;
        if (timer.tick >= ticks) {
          timer.cancel();
          inBonusRound = false;
          return;
        }
        double xPos = random.nextDouble() * (screenWidth - 30);
        items.add(FallingItem(
          x: xPos,
          y: -30,
          type: FallingItemType.coin,
          size: 20,
          value: 1,
        ));
      });
    });
  }

  void restartGame() {
    setState(() {
      obstacles.clear();
      items.clear();
      burstCoins.clear();
      particles.clear();
      score = 0;
      speed = 3.0;
      gameOver = false;
      butterflyX = screenWidth / 2 - 25;
      _controller.repeat();
    });
  }

  bool _isColliding(double bx, double by, double bw, double bh, double ox,
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
            // Particles
            for (var p in particles)
              Positioned(
                left: p.x,
                top: p.y,
                child: Container(
                  width: p.size,
                  height: p.size,
                  decoration: BoxDecoration(
                      color: p.color, shape: BoxShape.circle),
                ),
              ),
            // Burst coins
            for (var b in burstCoins)
              Positioned(
                  left: b.x,
                  top: b.y,
                  child: Text('🪙', style: TextStyle(fontSize: b.size))),
            // Items
            for (var item in items)
              Positioned(
                left: item.x,
                top: item.y,
                child: Text(
                  item.type == FallingItemType.coin
                      ? '🪙'
                      : item.type == FallingItemType.magicOrb
                          ? '✨'
                          : item.type == FallingItemType.gem
                              ? '💎'
                              : item.type == FallingItemType.lightning
                                  ? '⚡'
                                  : '💰',
                  style: TextStyle(fontSize: item.size),
                ),
              ),
            // Obstacles
            for (var obs in obstacles)
              Positioned(
                left: obs.x,
                top: obs.y,
                child: Text(
                  obs.type,
                  style: TextStyle(fontSize: 50),
                ),
              ),
            // Butterfly
            Positioned(
              left: butterflyX,
              top: butterflyY,
              child: Text('🦋', style: TextStyle(fontSize: 50)),
            ),
            // Score
            Positioned(
              top: 40,
              left: 20,
              child: Text('Coins: $score',
                  style: TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            // Gems
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
            // Bonus popup
            if (bonusPopupVisible)
              Center(
                child: Container(
                  color: Colors.black87,
                  padding: EdgeInsets.all(20),
                  child: Text('BONUS ROUND!',
                      style: TextStyle(
                          fontSize: 30,
                          color: Colors.yellowAccent,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            // Game over
            if (gameOver)
              Center(
                child: Container(
                  color: Colors.black54,
                  padding: EdgeInsets.all(20),
                  child: Text('GAME OVER\nTap to Restart',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Classes ----------------
class Obstacle {
  final double x, y, drift;
  final String type;
  Obstacle({required this.x, required this.y, required this.type, this.drift = 0});
  Obstacle copyWith({double? x, double? y, double? drift}) =>
      Obstacle(x: x ?? this.x, y: y ?? this.y, type: type, drift: drift ?? this.drift);
}

class FallingItem {
  final double x, y, size;
  final FallingItemType type;
  final int? value;
  FallingItem({required this.x, required this.y, required this.type, this.size = 20, this.value});
  FallingItem copyWith({double? x, double? y}) => FallingItem(
      x: x ?? this.x, y: y ?? this.y, type: type, size: size, value: value);
}

enum FallingItemType { coin, magicOrb, gem, star, bill, moneyBag, lightning }

class BurstCoin {
  final double x, y, dx, dy;
  final int life;
  final double size;
  final int value;
  BurstCoin({required this.x, required this.y, required this.dx, required this.dy, required this.life, required this.size, required this.value});
  BurstCoin copyWith({double? x, double? y, double? dx, double? dy}) => BurstCoin(
      x: x ?? this.x, y: y ?? this.y, dx: dx ?? this.dx, dy: dy ?? this.dy, life: life, size: size, value: value);
}

class StaticParticle {
  final double x, y;
  final double size;
  final Color color;
  StaticParticle({required this.x, required this.y, required this.size, required this.color});
  StaticParticle copyWith({double? y}) => StaticParticle(x: x, y: y ?? this.y, size: size, color: color);
}
