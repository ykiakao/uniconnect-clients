import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniconnect/features/auth/models/app_user.dart';
import 'package:uniconnect/features/auth/providers/auth_provider.dart';
import 'package:uniconnect/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:uniconnect/features/tenant/models/tenant_context.dart';
import 'package:uniconnect/features/tenant/providers/tenant_provider.dart';

void main() {
  const tenant = TenantContext(
    id: 'tenant-1',
    name: 'EduKMais',
    slug: 'edukmais',
    plan: SubscriptionPlan.growth,
    status: SubscriptionStatus.trialing,
    activeUsers: 2,
  );
  const teacher = AppUser(
    id: 'teacher-1',
    name: 'Ana Lima',
    email: 'teacher-test@example.invalid',
    role: UserRole.teacher,
    tenant: tenant,
    course: 'Engenharia de Software',
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders professor identity without unsupported actions',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => teacher),
          currentTenantProvider.overrideWith((ref) => tenant),
        ],
        child: const MaterialApp(home: TeacherDashboardPage()),
      ),
    );

    expect(find.text('Ana Lima'), findsOneWidget);
    expect(find.text('Professor'), findsOneWidget);
    expect(find.text('teacher-test@example.invalid'), findsOneWidget);
    expect(find.text('EduKMais'), findsOneWidget);
    expect(find.text('Ambiente de demonstração'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Vínculo acadêmico'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Vínculo acadêmico'), findsOneWidget);
    expect(find.text('Engenharia de Software'), findsOneWidget);
    expect(find.text('Criar atividade'), findsNothing);
    expect(find.text('Turmas'), findsNothing);
    expect(find.text('Alunos'), findsNothing);
    expect(find.text('Pendências'), findsNothing);
    expect(find.text('Lançar notas'), findsNothing);
    expect(find.text('Enviar comunicados'), findsNothing);
  });
}
