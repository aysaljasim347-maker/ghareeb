import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';

class ReliefNetLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showText;

  const ReliefNetLogo({
    super.key,
    this.size = 40,
    this.color,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? AppTheme.primaryColor;
    
    final logo = SvgPicture.string(
      '''
<svg width="100" height="100" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- Outer Net Pattern (Simplified for small sizes) -->
  <circle cx="50" cy="50" r="46" stroke="${_colorToHex(logoColor)}" stroke-width="4" stroke-dasharray="8 4"/>
  
  <!-- Main Relief Symbol: Stylized Hands/Heart -->
  <path d="M50 75C50 75 22 56 22 37C22 24 38 21 50 34C62 21 78 24 78 37C78 56 50 75 50 75Z" fill="${_colorToHex(logoColor)}"/>
  
  <!-- Recognition Detail: Inner Mesh Line -->
  <path d="M30 50H70" stroke="white" stroke-width="3" stroke-linecap="round" opacity="0.8"/>
  <path d="M50 35V65" stroke="white" stroke-width="3" stroke-linecap="round" opacity="0.8"/>
</svg>
''',
      width: size,
      height: size,
    );

    if (!showText) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 12),
        Text(
          'ReliefNet',
          style: TextStyle(
            fontSize: size * 0.6,
            fontWeight: FontWeight.w800,
            color: logoColor,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
