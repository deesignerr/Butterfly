import 'package:flutter/material.dart';
import 'dart:math';

void main() => runApp(FlutterButterfly());

class FlutterButterfly extends StatelessWidget {
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

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late double butterflyX;
  late double butterflyY;
  double speed = 3.0;
  int score = 0;
  bool gameOver = false;

  final Random random = Random();
  late AnimationController _controller;
  late double screenWidth;
  late double screenHeight;

  List<Obstacle> obstacles = [];
  List<Offset> coins = [];
  List<Particle> particles = [];

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
      // Increase speed every 10 coins by 2%
      if (score != 0 && score % 10 == 0) {
        speed = 3.0 * (1 + 0.02 * (score ~/ 10));
      }

      // Generate obstacles
      if (obstacles.isEmpty || obstacles.last.y > 120) {
        obstacles.add(
          Obstacle(
            x: random.nextDouble() * (screenWidth - 50),
            y: -50,
            type: obstacleTypes[random.nextInt(obstacleTypes.length)],
            drift: random.nextDouble() * 1.5 - 0.75,
          ),
        );
      }

      // Generate coins
      if (coins.isEmpty || coins.last.dy > 80) {
        coins.add(Offset(random.nextDouble() * (screenWidth - 20), -30));
      }

      // Move obstacles
      obstacles = obstacles
          .map((o) =>
              o.copyWith(y: o.y + speed, x: (o.x + o.drift).clamp(0.0, screenWidth - 50)))
          .toList();

      // Move coins downward
      coins = coins.map((c) => Offset(c.dx, c.dy + speed)).toList();

      // Move particles
      particles = particles
          .map((p) => p.copyWith(x: p.x + p.dx, y: p.y + p.dy, life: p.life - 1))
          .toList();
      particles.removeWhere((p) => p.life <= 0);

      // Check coin collisions using rectangle-based detection
      coins.removeWhere((coin) {
        if (isColliding(butterflyX, butterflyY, 50, 50, coin.dx, coin.dy, 20, 20)) {
          score += 1;
          for (int i = 0; i < 5; i++) {
            particles.add(Particle(
              x: butterflyX + 25,
              y: butterflyY + 25,
              dx: random.nextDouble() * 4 - 2,
              dy: random.nextDouble() * -4,
              life: 20 + random.nextInt(20),
              color: Colors.yellowAccent,
            ));
          }
          return true;
        }
        return false;
      });

      // Check collisions with obstacles using rectangle-based detection
      for (var obs in obstacles) {
        if (isColliding(butterflyX, butterflyY, 50, 50, obs.x, obs.y, 50, 50)) {
          gameOver = true;
          _controller.stop();
          break;
        }
      }

      // Remove off-screen obstacles and coins
      obstacles.removeWhere((o) => o.y > screenHeight);
      coins.removeWhere((c) => c.dy > screenHeight);
    });
  }

  void moveButterfly(DragUpdateDetails details) {
    if (!gameOver) {
      setState(() {
        butterflyX += details.delta.dx;
        butterflyX = butterflyX.clamp(0.0, screenWidth - 50);
      });
    }
  }

  void restartGame() {
    setState(() {
      obstacles.clear();
      coins.clear();
      particles.clear();
      score = 0;
      speed = 3.0;
      gameOver = false;
      butterflyX = screenWidth / 2 - 25;

      _controller.repeat();
    });
  }

  // Rectangle collision detection
  bool isColliding(double bx, double by, double bw, double bh,
      double ox, double oy, double ow, double oh) {
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
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                      color: p.color.withOpacity(p.life / 40),
                      shape: BoxShape.circle),
                ),
              ),
            // Coins (falling)
            for (var coin in coins)
              Positioned(
                left: coin.dx,
                top: coin.dy,
                child: Text('🪙', style: TextStyle(fontSize: 20)),
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
            // Game Over overlay
            if (gameOver)
              Center(
                child: Container(
                  color: Colors.black54,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'GAME OVER\nTap to Restart',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
