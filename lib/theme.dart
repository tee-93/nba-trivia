import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Court-inspired palette and type: hardwood, painted lines, scoreboard digits.
class Court {
  static const woodDark = Color(0xFF2A1B12);
  static const wood = Color(0xFF3D2817);
  static const woodLight = Color(0xFF5A3A1F);
  static const line = Color(0xFFF2E6D0);
  static const orange = Color(0xFFFF7A1A);
  static const amber = Color(0xFFFFB000);
  static const board = Color(0xFF0B0B0D);
  static const good = Color(0xFF2E9E5B);
  static const bad = Color(0xFFD64545);

  /// Big condensed headline type.
  static TextStyle display(double size, {Color color = line}) =>
      GoogleFonts.bebasNeue(
        fontSize: size,
        color: color,
        letterSpacing: 1.5,
        height: 1.05,
      );

  /// Scoreboard digits.
  static TextStyle digits(double size, {Color color = amber}) =>
      GoogleFonts.teko(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        height: 1,
      );

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: Brightness.dark,
      ).copyWith(primary: orange, surface: wood),
      scaffoldBackgroundColor: woodDark,
    );
    return base.copyWith(
      // google_fonts' TextTheme helpers use a different TextTheme type, so
      // apply the font by family name instead (building the style loads it).
      textTheme: base.textTheme.apply(
        bodyColor: line,
        displayColor: line,
        fontFamily: GoogleFonts.barlow().fontFamily,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: display(26),
      ),
      cardTheme: CardThemeData(
        color: Colors.black.withValues(alpha: 0.35),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line.withValues(alpha: 0.15)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.barlow(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: line,
          side: BorderSide(color: line.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.25),
          foregroundColor: line,
          selectedBackgroundColor: orange,
          selectedForegroundColor: Colors.black,
          side: BorderSide(color: line.withValues(alpha: 0.25)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? orange : line,
        ),
      ),
    );
  }
}

/// Hardwood floor with faint painted court lines.
class CourtBackground extends StatelessWidget {
  const CourtBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Court.woodDark, Court.wood],
            ),
          ),
        ),
        CustomPaint(painter: _CourtPainter()),
        child,
      ],
    );
  }
}

class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final plank = Paint()
      ..color = Court.line.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var x = 0.0; x < s.width; x += s.width / 9) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), plank);
    }
    final p = Paint()
      ..color = Court.line.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final cx = s.width / 2;
    // Lane and free-throw circle at the bottom of the screen.
    canvas.drawRect(
      Rect.fromLTRB(
        s.width * 0.28,
        s.height * 0.74,
        s.width * 0.72,
        s.height + 4,
      ),
      p,
    );
    canvas.drawCircle(Offset(cx, s.height * 0.74), s.width * 0.22, p);
    // Three-point arc.
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(cx, s.height * 1.02),
        radius: s.width * 0.68,
      ),
      math.pi * 1.08,
      math.pi * 0.84,
      false,
      p,
    );
    // Half-court line and centre circle at the top.
    canvas.drawLine(
      Offset(0, s.height * 0.02),
      Offset(s.width, s.height * 0.02),
      p,
    );
    canvas.drawCircle(Offset(cx, s.height * 0.02), s.width * 0.18, p);
  }

  @override
  bool shouldRepaint(_CourtPainter old) => false;
}

/// A black scoreboard panel with a small label and amber digits.
class ScoreBoard extends StatelessWidget {
  const ScoreBoard({
    super.key,
    required this.label,
    required this.value,
    this.alert = false,
    this.width,
  });
  final String label;
  final String value;
  final bool alert;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Court.board,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Court.line.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.4,
              color: Court.line.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: Court.digits(30, color: alert ? Court.bad : Court.amber),
          ),
        ],
      ),
    );
  }
}
