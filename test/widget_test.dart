import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_organizer/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NexusOrganizerApp());
  });
}
