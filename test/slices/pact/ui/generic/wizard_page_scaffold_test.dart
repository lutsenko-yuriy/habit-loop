import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_page_scaffold.dart';

Widget _wrap({
  int currentPage = 0,
  int pageCount = 3,
  ValueChanged<int>? onPageChanged,
  Key? pageViewKey,
  Widget Function(int, FocusNode)? pageBuilder,
}) {
  return MaterialApp(
    home: Scaffold(
      body: WizardPageScaffold(
        currentPage: currentPage,
        pageCount: pageCount,
        onPageChanged: onPageChanged ?? (_) {},
        hintText: 'Swipe to move',
        hintTextColor: Colors.grey,
        pageViewKey: pageViewKey,
        pageBuilder: pageBuilder ?? (index, _) => Text('Page $index'),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a PageView', (tester) async {
    await tester.pumpWidget(_wrap(pageViewKey: const Key('test-pageview')));
    expect(find.byKey(const Key('test-pageview')), findsOneWidget);
  });

  testWidgets('shows hint text', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Swipe to move'), findsOneWidget);
  });

  testWidgets('renders pageCount pages via pageBuilder', (tester) async {
    await tester.pumpWidget(_wrap(pageCount: 3));
    expect(find.text('Page 0'), findsOneWidget);
  });

  testWidgets('passes FocusNode to pageBuilder', (tester) async {
    FocusNode? receivedNode;
    await tester.pumpWidget(_wrap(
      pageBuilder: (index, focusNode) {
        if (index == 0) receivedNode = focusNode;
        return Text('Page $index');
      },
    ));
    expect(receivedNode, isNotNull);
  });

  testWidgets('hint text uses hintTextColor', (tester) async {
    await tester.pumpWidget(_wrap());
    final text = tester.widget<Text>(find.text('Swipe to move'));
    expect(text.style?.color, Colors.grey);
  });
}
