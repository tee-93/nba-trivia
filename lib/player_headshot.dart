import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'models.dart';
import 'theme.dart';

/// A round player headshot for personal builds. Renders nothing in the public
/// build, and a plain placeholder if the image can't be fetched.
class PlayerHeadshot extends StatelessWidget {
  const PlayerHeadshot({super.key, required this.player, required this.size});

  final Player player;
  final double size;

  static String urlFor(Player p) =>
      'https://a.espncdn.com/i/headshots/nba/players/full/${p.id}.png';

  @override
  Widget build(BuildContext context) {
    if (!kPersonal) return const SizedBox.shrink();
    final placeholder = Icon(
      Icons.person,
      size: size * 0.6,
      color: Court.line.withValues(alpha: 0.4),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Court.line.withValues(alpha: 0.3), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: urlFor(player),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => Center(child: placeholder),
        errorWidget: (_, _, _) => Center(child: placeholder),
      ),
    );
  }
}
