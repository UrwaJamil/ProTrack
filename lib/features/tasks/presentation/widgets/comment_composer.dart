import 'package:flutter/material.dart';

import '../../data/task_comment.dart';

/// "Write a comment…" field with a send button, pinned under the comment
/// list. [onSend] returns whether the comment was saved; the field is
/// cleared only then, so a failed send keeps the text.
///
/// The attach button is a disabled stub until Cloud Storage exists
/// (CLAUDE.md decision 8).
class CommentComposer extends StatefulWidget {
  const CommentComposer({super.key, required this.onSend});

  final Future<bool> Function(String text) onSend;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => !_sending && _controller.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    final ok = await widget.onSend(_controller.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: [
              const IconButton(
                tooltip: 'Attachments are not available yet',
                onPressed: null,
                icon: Icon(Icons.attach_file),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: commentMaxLength,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Write a comment…',
                    counterText: '',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send comment',
                onPressed: _canSend ? _send : null,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
