import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/main.dart';

void main() {
  testWidgets('renders UniConnect login', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.pumpWidget(const ProviderScope(child: UniConnectApp()));

    expect(find.text('UniConnect'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
