const helpNoteMaxLength = 500;

/// A task's `helpNote {text, taggedUserId?, taggedSkill?, requestId?}`:
/// what's blocking the assignee and who they asked for help (Phase 4).
/// [requestId] is the id of the request's `help_requested` history entry;
/// the helper accepts at `history/accept_<requestId>`, which the rules
/// allow once.
///
/// Kept out of `Task` (an existing model that stays untouched); read and
/// written by `TaskActivityRepository`.
class HelpNote {
  const HelpNote({
    required this.text,
    this.taggedUserId,
    this.taggedSkill,
    this.requestId,
  });

  final String text;
  final String? taggedUserId;
  final String? taggedSkill;
  final String? requestId;

  HelpNote withRequestId(String id) => HelpNote(
    text: text,
    taggedUserId: taggedUserId,
    taggedSkill: taggedSkill,
    requestId: id,
  );

  /// `null` for a missing or malformed field.
  static HelpNote? fromField(Object? value) {
    if (value is! Map) return null;
    final text = value['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final user = value['taggedUserId'];
    final skill = value['taggedSkill'];
    final request = value['requestId'];
    return HelpNote(
      text: text,
      taggedUserId: user is String ? user : null,
      taggedSkill: skill is String ? skill : null,
      requestId: request is String ? request : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    if (taggedUserId != null) 'taggedUserId': taggedUserId,
    if (taggedSkill != null) 'taggedSkill': taggedSkill,
    if (requestId != null) 'requestId': requestId,
  };
}
