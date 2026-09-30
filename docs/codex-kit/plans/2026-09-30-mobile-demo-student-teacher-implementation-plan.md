# Mobile Student And Teacher Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `.codex-kit/skills/subagent-driven-development/` (recommended) or `.codex-kit/skills/executing-plans/` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a student-first EduKMais mobile demonstration with read-only activity details and a minimal, role-aware professor dashboard.

**Architecture:** Keep student academic retrieval on the existing `activitiesProvider` and `AcademicApiService` path. Make the activity detail page accurately read-only, and make the teacher dashboard a presentation of `currentUserProvider` and `currentTenantProvider` only; no API contract, route, or persistence change is needed.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, flutter_test.

---

## File Structure

- Modify: `uniconnect_flutter_base/lib/features/activities/presentation/activity_detail_page.dart` - remove simulated actions and static points from the read-only detail screen.
- Modify: `uniconnect_flutter_base/lib/features/teacher/presentation/teacher_dashboard_page.dart` - replace simulated teacher metrics and operations with session-derived identity and tenant information.
- Create: `uniconnect_flutter_base/test/activity_detail_page_test.dart` - lock the activity detail screen to its read-only behavior.
- Create: `uniconnect_flutter_base/test/teacher_dashboard_page_test.dart` - verify the teacher dashboard renders the authenticated professor and institution without unsupported actions.
- Modify: `uniconnect_flutter_base/test/app_router_guard_test.dart` - preserve an explicit route-guard assertion for the professor route.

### Task 1: Lock The Student Activity Detail To Read-Only

**Files:**
- Create: `uniconnect_flutter_base/test/activity_detail_page_test.dart`
- Modify: `uniconnect_flutter_base/lib/features/activities/presentation/activity_detail_page.dart`

- [ ] **Step 1: Write the failing widget test for the supported detail content**

```dart
testWidgets('renders activity details without unsupported actions', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activitiesProvider.overrideWith((ref) async => [demoActivity]),
      ],
      child: const MaterialApp(home: ActivityDetailPage(activityId: 'activity-1')),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Pesquisa aplicada'), findsOneWidget);
  expect(find.text('Metodos Quantitativos'), findsOneWidget);
  expect(find.text('Enviar mensagem'), findsNothing);
  expect(find.text('Realizar atividade'), findsNothing);
  expect(find.text('10.0 pontos'), findsNothing);
});
```

- [ ] **Step 2: Run the new test and confirm it fails on the current simulated controls**

Run: `flutter test test/activity_detail_page_test.dart`

Expected: FAIL because the page still renders `Enviar mensagem`, `Realizar atividade`, and `10.0 pontos`.

- [ ] **Step 3: Implement the minimal read-only detail UI**

Remove the `app_buttons.dart` import, the message and activity buttons, and the static value card from `_ActivityDetailContent`. Keep the deadline, instructions, optional material list, teacher card, loading, error, and missing-activity states.

```dart
Text(
  activity.title,
  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        height: 1.12,
      ),
),
const SizedBox(height: AppSpacing.lg),
_InfoPill(
  icon: Icons.event_outlined,
  label: 'Prazo',
  value: activity.dueLabel,
),
```

- [ ] **Step 4: Make missing API fields explicit instead of inventing content**

Replace the fallback criteria checklist with a muted no-information message.

```dart
if (activity.criteria.isEmpty)
  const Text(
    'Os criterios de avaliacao nao foram informados para esta atividade.',
    style: TextStyle(color: AppColors.muted),
  )
else
  for (final criterion in activity.criteria) _ChecklistItem(text: criterion),
```

- [ ] **Step 5: Run the focused test and record a passing result**

Run: `flutter test test/activity_detail_page_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit the read-only student detail change**

```bash
git add uniconnect_flutter_base/lib/features/activities/presentation/activity_detail_page.dart uniconnect_flutter_base/test/activity_detail_page_test.dart
git commit -m "feat: keep activity details read only"
```

### Task 2: Reduce The Professor Dashboard To Supported Information

**Files:**
- Create: `uniconnect_flutter_base/test/teacher_dashboard_page_test.dart`
- Modify: `uniconnect_flutter_base/lib/features/teacher/presentation/teacher_dashboard_page.dart`

- [ ] **Step 1: Write the failing dashboard widget test**

```dart
testWidgets('renders professor identity and institution without unsupported actions',
    (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => demoTeacher),
        currentTenantProvider.overrideWith((ref) => demoTenant),
      ],
      child: const MaterialApp(home: TeacherDashboardPage()),
    ),
  );

  expect(find.text('Ana'), findsOneWidget);
  expect(find.text('Professor'), findsOneWidget);
  expect(find.text('EduKMais'), findsOneWidget);
  expect(find.text('Criar atividade'), findsNothing);
  expect(find.text('Lancar notas'), findsNothing);
  expect(find.text('Enviar comunicados'), findsNothing);
});
```

- [ ] **Step 2: Run the new test and confirm it fails on the current simulated teacher controls**

Run: `flutter test test/teacher_dashboard_page_test.dart`

Expected: FAIL because the dashboard still renders static metrics and action cards.

- [ ] **Step 3: Render only session-derived professor context**

Replace the metrics, `SectionHeader`, and `_TeacherActionCard` content with one context card. Keep the existing logout dialog and route.

```dart
AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Professor', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Text(user?.name ?? 'Professor', style: Theme.of(context).textTheme.titleLarge),
      Text(user?.email ?? '', style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: AppSpacing.md),
      Text(tenant?.name ?? 'Instituicao nao identificada'),
    ],
  ),
),
```

- [ ] **Step 4: Run the focused dashboard test and record a passing result**

Run: `flutter test test/teacher_dashboard_page_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the minimal professor dashboard**

```bash
git add uniconnect_flutter_base/lib/features/teacher/presentation/teacher_dashboard_page.dart uniconnect_flutter_base/test/teacher_dashboard_page_test.dart
git commit -m "feat: simplify professor demo dashboard"
```

### Task 3: Protect The Two-Profile Demonstration Contract

**Files:**
- Modify: `uniconnect_flutter_base/test/app_router_guard_test.dart`

- [ ] **Step 1: Add an explicit redirect test for a professor entering the student route**

```dart
test('professor em rota de aluno vai para dashboard professor', () {
  final redirect = computeRedirect(
    isRestoring: false,
    isAuthenticated: true,
    userRole: UserRole.teacher,
    location: AppRoutes.studentDashboard,
  );

  expect(redirect, AppRoutes.teacherDashboard);
});
```

- [ ] **Step 2: Run the route test and confirm the expected behavior**

Run: `flutter test test/app_router_guard_test.dart`

Expected: PASS if the existing role guard already redirects the teacher route correctly; otherwise FAIL and expose the smallest required guard adjustment.

- [ ] **Step 3: Add the minimal guard condition only if Step 2 fails**

Modify `uniconnect_flutter_base/lib/core/router/app_router.dart` only when the new test fails.

```dart
UserRole.teacher when isStudentRoute => AppRoutes.teacherDashboard,
```

- [ ] **Step 4: Re-run the route test**

Run: `flutter test test/app_router_guard_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the route-contract test and any necessary guard change**

```bash
git add uniconnect_flutter_base/test/app_router_guard_test.dart uniconnect_flutter_base/lib/core/router/app_router.dart
git commit -m "test: protect student and teacher demo routes"
```

### Task 4: Verify The Presentation Flow

**Files:**
- Modify: `uniconnect_flutter_base/test/activity_detail_page_test.dart`
- Modify: `uniconnect_flutter_base/test/teacher_dashboard_page_test.dart`

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`

Expected: no analyzer errors.

- [ ] **Step 2: Run the complete Flutter test suite**

Run: `flutter test`

Expected: PASS for all tests.

- [ ] **Step 3: Run the presentation build against EduKMais**

Run: `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=API_BASE_URL=https://uniconnect-api-ht5x.onrender.com/api/v1 --dart-define=TENANT_SLUG=edukmais`

Expected: the application starts and allows a manual check with the configured EduKMais student and professor accounts.

- [ ] **Step 4: Manually validate both profile flows**

Student: sign in, open dashboard, activities, one detail, then grades.

Professor: sign in, confirm the dashboard shows name, role, email, and EduKMais only; confirm no teacher operation is exposed.

- [ ] **Step 5: Commit any verification-only test adjustment and record validation evidence**

```bash
git add uniconnect_flutter_base/test
git commit -m "test: verify mobile demo flows"
```

Skip this commit when no verification-only test file changed.
