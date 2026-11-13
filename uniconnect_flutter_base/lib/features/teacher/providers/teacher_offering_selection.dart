import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import 'teacher_activity_provider.dart';

typedef TeacherOfferingSelection = ({String? classId, bool revoked});

final teacherOfferingSelectionProvider = NotifierProvider<
    TeacherOfferingSelectionController,
    TeacherOfferingSelection>(TeacherOfferingSelectionController.new);

class TeacherOfferingSelectionController
    extends Notifier<TeacherOfferingSelection> {
  @override
  TeacherOfferingSelection build() {
    ref.watch(teacherNotesSessionProvider);
    if (ref.read(currentUserProvider)?.role != UserRole.teacher) {
      return (classId: null, revoked: false);
    }
    ref.listen(teacherOfferingsProvider, (_, next) {
      if (next.isLoading || next.hasError || !next.hasValue) return;
      final rows = next.requireValue;
      final previous = state.classId;
      if (previous != null && !rows.any((row) => row.id == previous)) {
        state = (classId: null, revoked: true);
        _invalidateOffer(previous);
      } else if (previous == null && !state.revoked && rows.length == 1) {
        state = (classId: rows.single.id, revoked: false);
      }
    });
    final offers = ref.read(teacherOfferingsProvider);
    return (
      classId:
          !offers.isLoading && !offers.hasError && offers.value?.length == 1
              ? offers.requireValue.single.id
              : null,
      revoked: false,
    );
  }

  void _invalidateOffer(String classId) {
    ref.invalidate(teacherActivitiesProvider(classId));
    ref.invalidate(teacherActivityPreviewProvider(classId));
    ref.invalidate(teacherEnrollmentsProvider(classId));
  }

  bool select(String classId) {
    if (ref.read(currentUserProvider)?.role != UserRole.teacher) return false;
    final offers = ref.read(teacherOfferingsProvider);
    if (offers.isLoading ||
        offers.hasError ||
        offers.value?.any((offer) => offer.id == classId) != true) {
      return false;
    }
    final previous = state.classId;
    if (previous != classId) {
      state = (classId: classId, revoked: false);
      if (previous != null) _invalidateOffer(previous);
    }
    return true;
  }
}

final selectedTeacherClassIdProvider = Provider<String?>((ref) {
  final selection = ref.watch(teacherOfferingSelectionProvider);
  final offers = ref.watch(teacherOfferingsProvider);
  if (offers.isLoading || offers.hasError) return null;
  return offers.value?.any((offer) => offer.id == selection.classId) == true
      ? selection.classId
      : null;
});

final teacherDraftGuardProvider = Provider<TeacherDraftGuard>((ref) {
  ref.watch(teacherNotesSessionProvider);
  return TeacherDraftGuard();
});

class TeacherDraftGuard {
  Future<bool> Function()? confirmExit;
  Future<bool> Function()? confirmReviewExit;
  Future<bool> Function()? confirmWorkExit;
  bool Function()? canExitNotes;
}
