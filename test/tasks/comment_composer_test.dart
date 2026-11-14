import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/app/theme.dart';
import 'package:team_project_manager/features/tasks/presentation/widgets/comment_composer.dart';

Future<List<String>> _pump(WidgetTester tester, {bool succeed = true}) async {
  final sent = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: CommentComposer(
          onSend: (text) async {
            sent.add(text);
            return succeed;
          },
        ),
      ),
    ),
  );
  return sent;
}

IconButton _send(WidgetTester tester) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

void main() {
  testWidgets('send is disabled until there is non-blank text', (tester) async {
    await _pump(tester);
    expect(_send(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(_send(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pump();
    expect(_send(tester).onPressed, isNotNull);
  });

  testWidgets('clears only after a successful send', (tester) async {
    final sent = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pump();
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();
    expect(sent, ['Hi']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('keeps the text when the send fails', (tester) async {
    await _pump(tester, succeed: false);
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pump();
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Hi',
    );
  });

  testWidgets('the attach button is a disabled stub', (tester) async {
    await _pump(tester);
    final attach = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.attach_file),
    );
    expect(attach.onPressed, isNull);
  });
}
