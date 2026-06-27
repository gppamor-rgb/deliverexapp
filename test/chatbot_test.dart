import 'package:deliverex/providers/chatbot_provider.dart';
import 'package:deliverex/screens/chatbot_screen.dart';
import 'package:deliverex/widgets/chatbot_chathead.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ChatbotProvider.instance.clear();
  });

  testWidgets('chatbot renders web-aligned main options', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatbotScreen()));
    await tester.pump();

    expect(find.text('Deliverex Assistant'), findsWidgets);
    expect(find.text('Track My Delivery'), findsOneWidget);
    expect(find.text('What is a Tracking ID?'), findsOneWidget);
    expect(find.text('Account Help'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
    expect(find.text('General Questions'), findsOneWidget);
  });

  testWidgets('account help includes Link Delivery', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatbotScreen()));
    await tester.pump();

    await tester.tap(find.text('Account Help'));
    await tester.pumpAndSettle();

    expect(find.text('Link Delivery'), findsOneWidget);
    expect(
      find.text(
        'Choose an account topic: Create Account, Login, Link Delivery, or Forgot Password.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tracking prompt uses Tracking ID wording', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatbotScreen()));
    await tester.pump();

    await tester.tap(find.text('Track My Delivery'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Please enter your Tracking ID.'),
      findsOneWidget,
    );
    expect(find.text('Enter Tracking ID...'), findsOneWidget);
  });

  testWidgets('chathead opens assistant bottom sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(),
          floatingActionButton: ChatbotChathead(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Open Deliverex Assistant'), findsOneWidget);
    expect(find.text('Assistant'), findsNothing);

    await tester.tap(find.byTooltip('Open Deliverex Assistant'));
    await tester.pumpAndSettle();

    expect(find.text('Deliverex Assistant'), findsOneWidget);
    expect(find.text('Track My Delivery'), findsOneWidget);
  });
}
