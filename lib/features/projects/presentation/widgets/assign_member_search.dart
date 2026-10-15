import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/labeled_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/app_user.dart';
import '../../../auth/data/user_repository.dart';
import '../../data/project.dart';
import '../../data/project_repository.dart';

const memberSearchMinChars = 3;
const memberSearchDebounce = Duration(milliseconds: 300);

/// "Assign Team Member": search registered users by email prefix and add
/// them to the project as Members (FR-2.2). Only existing accounts can be
/// added; people already in the project are hidden from the results.
class AssignMemberSearch extends ConsumerStatefulWidget {
  const AssignMemberSearch({super.key, required this.project, this.focusNode});

  final Project project;
  final FocusNode? focusNode;

  @override
  ConsumerState<AssignMemberSearch> createState() => _AssignMemberSearchState();
}

class _AssignMemberSearchState extends ConsumerState<AssignMemberSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  bool _failed = false;
  List<AppUser> _results = const [];
  final _adding = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = emailLowerFor(text);
    setState(() {
      _query = query;
      _failed = false;
      if (query.length < memberSearchMinChars) {
        _results = const [];
        _searching = false;
      }
    });
    if (query.length < memberSearchMinChars) return;
    _debounce = Timer(memberSearchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final users = await ref
          .read(userRepositoryProvider)
          .searchByEmailPrefix(query);
      if (!mounted || query != _query) return; // typed on since
      setState(() {
        _results = users;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || query != _query) return;
      setState(() {
        _failed = true;
        _searching = false;
      });
    }
  }

  Future<void> _add(AppUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding.add(user.uid));
    try {
      await ref
          .read(projectRepositoryProvider)
          .addMember(widget.project.id, user.uid);
      messenger.showSnackBar(
        SnackBar(content: Text('${user.name} added to the project')),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't add ${user.name}. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _adding.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _results
        .where((u) => !widget.project.members.containsKey(u.uid))
        .toList();
    return LabeledField(
      label: 'Assign Team Member',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search by email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: 8),
          _resultsView(context, candidates),
        ],
      ),
    );
  }

  Widget _resultsView(BuildContext context, List<AppUser> candidates) {
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (_query.length < memberSearchMinChars) {
      return Text(
        'Type at least $memberSearchMinChars characters of their email. '
        'Only people with a ProTrack account can be added.',
        style: muted,
      );
    }
    if (_failed) {
      return Text(
        "Search didn't work. Check your connection and try again.",
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    if (_searching) return const SizedBox.shrink();
    if (candidates.isEmpty) {
      return Text(
        _results.isEmpty
            ? 'No registered user matches "$_query".'
            : 'Everyone matching "$_query" is already in this project.',
        style: muted,
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < candidates.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: UserAvatar(
                uid: candidates[i].uid,
                name: candidates[i].name,
                size: 40,
              ),
              title: Text(
                candidates[i].name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                candidates[i].email,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
              trailing: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: _adding.contains(candidates[i].uid)
                    ? null
                    : () => _add(candidates[i]),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
