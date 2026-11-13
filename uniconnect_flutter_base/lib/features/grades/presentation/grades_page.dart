import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/academic_demo_frame.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../providers/student_report_card_provider.dart';
import '../widgets/student_report_card_section.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studentReportSessionProvider);
    final demo = ref.watch(syntheticDemoEnabledProvider);

    return Scaffold(
      appBar: const AppHeader(
        title: 'Quadro de notas',
        showProfile: true,
        fallbackRoute: AppRoutes.studentDashboard,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 3),
      body: SafeArea(
        child: AcademicDemoFrame(
          child: AcademicContent(
            child: RefreshIndicator(
              onRefresh: () async {
                if (session == null) return;
                final offerings = studentReportOfferingsProvider(session);
                ref.invalidate(offerings);
                ref.invalidate(studentReportCardProvider);
                try {
                  await ref.read(offerings.future);
                } catch (_) {
                  // The report section presents the error and retry action.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (session != null)
                    StudentReportCardSection(
                        key: ValueKey(session), session: session)
                  else
                    EmptyStateWidget(
                      icon: LucideIcons.graduationCap,
                      title: 'Boletim acadêmico indisponível',
                      subtitle: demo
                          ? 'O modo de demonstração não consulta o boletim oficial.'
                          : 'Entre com uma conta de aluno para consultar seu boletim.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
