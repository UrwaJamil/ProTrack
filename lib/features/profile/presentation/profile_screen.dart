import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/app_user.dart';
import 'profile_settings_section.dart';
import 'skill_tags_editor.dart';

/// Profile tab for both roles: editable name + skill tags, the default
/// dashboard role shown read-only (a project's own `members` map is what
/// decides role per project), then settings and Sign out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  List<String> _skillTags = [];
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            name: _nameController.text.trim(),
            skillTags: _skillTags,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_initialized) {
      _nameController.text = profile.name;
      _skillTags = List.of(profile.skillTags);
      _initialized = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Email'),
                child: Text(profile.email),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Default role'),
                child: Text(profile.defaultRole.label),
              ),
              const SizedBox(height: 24),
              SkillTagsEditor(
                tags: _skillTags,
                onChanged: (tags) => setState(() => _skillTags = tags),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
              const SizedBox(height: 32),
              ProfileSettingsSection(
                showAnalytics: profile.defaultRole == UserRole.leader,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
