import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Up to two initials from a display name ("Ada Lovelace" → "AL").
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
  final result = letters.join();
  return result.isEmpty ? '?' : result;
}

/// Initials in a circle, colored deterministically from [uid] so a person
/// keeps the same color everywhere.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.size = 36,
    this.ringColor,
  });

  final String uid;
  final String name;
  final double size;

  /// Draws a 2px ring (e.g. the card surface) so overlapping avatars separate.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).appColors.avatarColors;
    final index = uid.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors[index],
        shape: BoxShape.circle,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: 2),
      ),
      child: Text(
        initialsFor(name),
        semanticsLabel: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Overlapping avatars with a "+N" badge once there are more than [max].
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    this.max = 3,
    this.size = 28,
  });

  final List<({String uid, String name})> people;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = theme.colorScheme.surface;
    final shown = people.take(max).toList();
    final extra = people.length - shown.length;
    final overlap = size * 0.3;
    final items = <Widget>[
      for (final p in shown)
        UserAvatar(uid: p.uid, name: p.name, size: size, ringColor: ring),
      if (extra > 0)
        Container(
          height: size,
          constraints: BoxConstraints(minWidth: size),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.appColors.chipBackground,
            borderRadius: BorderRadius.circular(size),
            border: Border.all(color: ring, width: 2),
          ),
          child: Text(
            '+$extra',
            style: TextStyle(
              color: theme.appColors.chipText,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ];
    return Semantics(
      label: '${people.length} ${people.length == 1 ? 'member' : 'members'}',
      excludeSemantics: true,
      // Every item but the last gets a slot narrower than itself, so the
      // next one paints over its right edge. Only avatars (fixed width)
      // are ever shrunk; the "+N" badge is always last.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            if (i < items.length - 1)
              Align(
                alignment: Alignment.centerLeft,
                widthFactor: (size - overlap) / size,
                child: items[i],
              )
            else
              items[i],
        ],
      ),
    );
  }
}
