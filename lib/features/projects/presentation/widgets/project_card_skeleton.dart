import 'package:flutter/material.dart';

/// Placeholder card shown while projects load: the same footprint as
/// [ProjectCard], with grey bars instead of content.
class ProjectCardSkeleton extends StatelessWidget {
  const ProjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bar = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget block(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Semantics(
      label: 'Loading project',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  block(72, 22),
                  const SizedBox(width: 10),
                  block(64, 14),
                ],
              ),
              const SizedBox(height: 14),
              block(200, 18),
              const SizedBox(height: 8),
              block(double.infinity, 12),
              const SizedBox(height: 6),
              block(160, 12),
              const SizedBox(height: 18),
              block(double.infinity, 6),
              const SizedBox(height: 18),
              Row(children: [block(96, 14), const Spacer(), block(64, 26)]),
            ],
          ),
        ),
      ),
    );
  }
}
