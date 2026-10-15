import 'package:flutter/material.dart';

import '../../../../core/widgets/pill_toggle.dart';
import '../../data/app_user.dart';

/// Admin / Member toggle (display labels for the stored `leader` /
/// `member` roles), used on the register and choose-role screens.
class RoleToggle extends StatelessWidget {
  const RoleToggle({super.key, required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return PillToggle<UserRole>(
      value: value,
      onChanged: onChanged,
      segments: [
        PillSegment(
          value: UserRole.leader,
          label: UserRole.leader.label,
          icon: Icons.workspace_premium,
        ),
        PillSegment(
          value: UserRole.member,
          label: UserRole.member.label,
          icon: Icons.person,
        ),
      ],
    );
  }
}
