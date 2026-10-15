import 'package:flutter/material.dart';

import '../../app/theme.dart';

const appName = 'ProTrack';
const _logoAsset = 'assets/Logo.png';

/// The ProTrack mark as a rounded-square "app icon" tile.
///
/// `assets/Logo.png` is a 1536×1024 transparent image that also contains a
/// low-contrast "ProTrack" wordmark, so this crops to the square around the
/// "P" mark (the wordmark is rendered as real text where needed). Swap the
/// crop for a plain `Image.asset` once a tight square export exists.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.borderColor});

  final double size;

  /// Defaults to the theme outline; the app bar passes its own edge color.
  final Color? borderColor;

  // The visible window, as fractions of the source image: a 640px square
  // centred on the mark (x≈475–1115, y≈92–732), stopping above the embedded
  // wordmark (which starts at y≈740).
  static const _windowWidth = 640 / 1536;
  static const _windowHeight = 640 / 1024;
  static const _windowAlignment = Alignment(0.06, -0.52);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(size * 0.24);
    return Semantics(
      label: '$appName logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.appColors.logoTile,
          borderRadius: radius,
          border: Border.all(color: borderColor ?? theme.colorScheme.outline),
        ),
        // Inset so the mark clears the rounded corners.
        padding: EdgeInsets.all(size * 0.14),
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: ClipRect(
              child: Align(
                alignment: _windowAlignment,
                widthFactor: _windowWidth,
                heightFactor: _windowHeight,
                child: Image.asset(
                  _logoAsset,
                  cacheWidth: 1024,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
