import 'package:flutter/material.dart';

/// The OratorIA wordmark (lockup). Picks the light- or dark-background variant
/// automatically. Uses the real brand PNGs shipped in `assets/brand/`.
class BrandLockup extends StatelessWidget {
  final double height;

  const BrandLockup({super.key, this.height = 40});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // "light" lockup = light-coloured wordmark for dark backgrounds; "dark" =
    // dark wordmark for light backgrounds.
    final asset = dark
        ? 'assets/brand/OratorIA-lockup-light.png'
        : 'assets/brand/OratorIA-lockup-dark.png';
    return Image.asset(asset, height: height, fit: BoxFit.contain);
  }
}

/// The OratorIA isotype (icon mark), for compact places like headers.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark
        ? 'assets/brand/OratorIA-isotype-inverted-1024.png'
        : 'assets/brand/OratorIA-isotype-1024.png';
    return Image.asset(asset, height: size, width: size, fit: BoxFit.contain);
  }
}
