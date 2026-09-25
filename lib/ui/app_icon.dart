import 'dart:io';

import 'package:flutter/material.dart';

import '../src/models.dart';
import 'theme.dart';

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.app, this.size = 40});

  final FlatpakApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = app.iconPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: path == null
          ? _fallback()
          : Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            ),
    );
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        color: erSurfaceAlt,
        alignment: Alignment.center,
        child: Text(
          app.name.isEmpty ? '?' : app.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: erAccent,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.45,
          ),
        ),
      );
}
