import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';

class TeacherOfferingLink extends ConsumerStatefulWidget {
  const TeacherOfferingLink({
    super.key,
    required this.classId,
    required this.child,
  });

  final String? classId;
  final Widget child;

  @override
  ConsumerState<TeacherOfferingLink> createState() =>
      _TeacherOfferingLinkState();
}

class _TeacherOfferingLinkState extends ConsumerState<TeacherOfferingLink> {
  String? _handled;
  String? _issue;
  bool _resolving = false;
  bool _opened = false;

  @override
  void didUpdateWidget(covariant TeacherOfferingLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _handled = null;
      _issue = null;
    }
  }

  Future<void> _resolve(String classId) async {
    if (!mounted ||
        widget.classId != classId ||
        _handled == classId ||
        _resolving ||
        ModalRoute.isCurrentOf(context) == false) {
      return;
    }
    final offers = ref.read(teacherOfferingsProvider);
    if (offers.isLoading || offers.hasError || !offers.hasValue) return;
    if (!offers.requireValue.any((offer) => offer.id == classId)) {
      setState(() {
        _handled = classId;
        _issue = 'A oferta deste link não está disponível para sua conta.';
      });
      return;
    }

    final session = ref.read(teacherNotesSessionProvider);
    final original = ref.read(teacherOfferingSelectionProvider).classId;
    _resolving = true;
    try {
      final guard = ref.read(teacherDraftGuardProvider);
      final confirm = guard.confirmReviewExit ?? guard.confirmWorkExit ?? guard.confirmExit;
      final accepted =
          original == classId || confirm == null || await confirm();
      if (!mounted ||
          widget.classId != classId ||
          ref.read(teacherNotesSessionProvider) != session ||
          ModalRoute.isCurrentOf(context) == false) {
        return;
      }
      final changed = accepted &&
          ref.read(teacherOfferingSelectionProvider).classId == original &&
          ref.read(teacherOfferingSelectionProvider.notifier).select(classId);
      setState(() {
        _handled = classId;
        _issue = changed
            ? null
            : accepted
                ? 'A oferta deste link não está disponível para sua conta.'
                : 'A troca de oferta não foi concluída.';
      });
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classId = widget.classId;
    final pending = classId != null && classId != _handled;
    final offers = pending ? ref.watch(teacherOfferingsProvider) : null;
    final current = ModalRoute.isCurrentOf(context) != false;
    if (pending &&
        current &&
        offers != null &&
        !offers.isLoading &&
        !offers.hasError &&
        offers.hasValue &&
        !_resolving) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve(classId));
    }
    final blocked = pending || _issue != null;
    if (!blocked) _opened = true;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_opened)
          ExcludeFocus(
            excluding: blocked,
            child: Offstage(
              offstage: blocked,
              child: TickerMode(enabled: !blocked, child: widget.child),
            ),
          ),
        if (blocked)
          Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_issue != null) ...[
                        Text(_issue!),
                        TextButton(
                          onPressed: () => setState(() => _issue = null),
                          child:
                              const Text('Continuar sem usar a oferta do link'),
                        ),
                      ] else if (offers?.hasError == true) ...[
                        const Text(
                            'Não foi possível validar a oferta do link.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(teacherOfferingsProvider),
                          child: const Text('Tentar novamente'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _handled = classId),
                          child:
                              const Text('Continuar sem usar a oferta do link'),
                        ),
                      ] else ...[
                        if (current) const CircularProgressIndicator(),
                        const Text('Validando a oferta do link...'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
