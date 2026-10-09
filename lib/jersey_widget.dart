import 'package:flutter/material.dart';

import 'config.dart';
import 'models.dart';
import 'team_logo.dart';

/// A tank-top jersey silhouette in the team's colours with a number on it.
class JerseyWidget extends StatelessWidget {
  const JerseyWidget({
    super.key,
    required this.team,
    required this.number,
    this.size = 220,
    this.showLogo = false,
  });

  final Team team;
  final String number;
  final double size;

  /// Personal builds only: draw the team logo above the number.
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final logo = kPersonal && showLogo && team.logoUrl != null;
    return SizedBox(
      width: size,
      height: size * 1.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size * 1.2),
            painter: _JerseyPainter(team.color, team.numberColor),
          ),
          Padding(
            padding: EdgeInsets.only(top: size * (logo ? 0.16 : 0.22)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logo) ...[
                  TeamLogo(team: team, size: size * 0.22),
                  SizedBox(height: size * 0.02),
                ],
                Text(
                  number,
                  style: TextStyle(
                    color: team.numberColor,
                    fontSize: size * (logo ? 0.38 : 0.42),
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  _JerseyPainter(this.fill, this.trim);
  final Color fill;
  final Color trim;

  @override
  void paint(Canvas canvas, Size s) {
    final sx = s.width / 100, sy = s.height / 120;
    Offset o(double x, double y) => Offset(x * sx, y * sy);

    final path = Path()
      ..moveTo(o(32, 0).dx, o(32, 0).dy)
      ..quadraticBezierTo(o(50, 26).dx, o(50, 26).dy, o(68, 0).dx, o(68, 0).dy)
      ..lineTo(o(84, 4).dx, o(84, 4).dy)
      ..quadraticBezierTo(
        o(86, 40).dx,
        o(86, 40).dy,
        o(100, 56).dx,
        o(100, 56).dy,
      )
      ..lineTo(o(100, 120).dx, o(100, 120).dy)
      ..lineTo(o(0, 120).dx, o(0, 120).dy)
      ..lineTo(o(0, 56).dx, o(0, 56).dy)
      ..quadraticBezierTo(o(14, 40).dx, o(14, 40).dy, o(16, 4).dx, o(16, 4).dy)
      ..close();

    canvas.drawShadow(path, Colors.black, 6, true);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.03
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_JerseyPainter old) =>
      old.fill != fill || old.trim != trim;
}
