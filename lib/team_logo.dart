import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'models.dart';

/// A team logo for personal builds. Renders nothing in the public build
/// (and nothing while loading or if the image can't be fetched).
class TeamLogo extends StatelessWidget {
  const TeamLogo({super.key, required this.team, required this.size});

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = team.logoUrl;
    if (!kPersonal || url == null) return SizedBox(width: size, height: size);
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => SizedBox(width: size, height: size),
      errorWidget: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}
