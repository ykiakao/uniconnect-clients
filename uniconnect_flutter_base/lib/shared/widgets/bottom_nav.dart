import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class UniBottomNav extends StatefulWidget {
  const UniBottomNav(
      {super.key, required this.currentIndex, this.isTeacher = false});

  final int currentIndex;
  final bool isTeacher;

  static const _studentDestinations = [
    NavigationDestination(
      icon: Icon(LucideIcons.house),
      selectedIcon: Icon(LucideIcons.house),
      label: 'Início',
    ),
    NavigationDestination(
      icon: Icon(LucideIcons.listChecks),
      selectedIcon: Icon(LucideIcons.listChecks),
      label: 'Atividades',
    ),
    NavigationDestination(
      icon: Icon(LucideIcons.messageSquareMore),
      selectedIcon: Icon(LucideIcons.messageSquareMore),
      label: 'Chat',
    ),
    NavigationDestination(
      icon: Icon(LucideIcons.graduationCap),
      selectedIcon: Icon(LucideIcons.graduationCap),
      label: 'Notas',
    ),
    NavigationDestination(
      icon: Icon(LucideIcons.landmark),
      selectedIcon: Icon(LucideIcons.landmark),
      label: 'Acadêmico',
    ),
  ];

  static const _teacherDestinations = [
    NavigationDestination(icon: Icon(LucideIcons.house), label: 'Início'),
    NavigationDestination(
      icon: Icon(LucideIcons.listChecks),
      label: 'Atividades',
    ),
    NavigationDestination(
        icon: Icon(LucideIcons.messageSquareMore), label: 'Chat'),
    NavigationDestination(
        icon: Icon(LucideIcons.graduationCap), label: 'Notas'),
  ];

  static const _studentRoutes = [
    AppRoutes.studentDashboard,
    AppRoutes.activities,
    AppRoutes.chat,
    AppRoutes.grades,
    AppRoutes.academic,
  ];

  static const _teacherRoutes = [
    AppRoutes.teacherDashboard,
    AppRoutes.teacherActivities,
    AppRoutes.teacherChat,
    AppRoutes.teacherGrades,
  ];

  List<NavigationDestination> get destinations =>
      isTeacher ? _teacherDestinations : _studentDestinations;

  List<String> get routes => isTeacher ? _teacherRoutes : _studentRoutes;

  @override
  State<UniBottomNav> createState() => _UniBottomNavState();
}

class _UniBottomNavState extends State<UniBottomNav>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 350);
  static final _travels = Expando<_NavTravel>();
  late final _selection = AnimationController(vsync: this, duration: _duration)
    ..addListener(_recordPosition);
  _NavTravel? _travel;
  late double _from = widget.currentIndex.toDouble();
  late double _to = widget.currentIndex.toDouble();
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final router = GoRouter.maybeOf(context);
    _travel = router == null
        ? (_travel ?? _NavTravel(widget.currentIndex.toDouble()))
        : (_travels[router] ??= _NavTravel(widget.currentIndex.toDouble()));
    if ((ModalRoute.isCurrentOf(context) ?? true) && _travel!.owner != this) {
      _animateTo(widget.currentIndex);
    } else if (_reduceMotion) {
      _selection.value = 1;
    }
  }

  double get _position =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_selection.value);

  void _recordPosition() {
    if (_travel?.owner == this) _travel!.position = _position;
  }

  void _animateTo(int index) {
    final travel = _travel!;
    final target = index.toDouble();
    final origin = travel.owner == null
        ? target
        : travel.owner == this
            ? _position
            : travel.position;
    travel.owner = this;
    _from = origin;
    _to = target;
    if (_reduceMotion || (target - origin).abs() < .0001) {
      _selection.value = 1;
      _recordPosition();
    } else {
      _selection.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant UniBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    if (_travel?.owner == this) _travel!.owner = null;
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final theme = Theme.of(context);
      final navTheme = NavigationBarTheme.of(context);
      final padding = MediaQuery.paddingOf(context);
      final availableWidth = constraints.maxWidth - padding.horizontal;
      final labelWidth = availableWidth / widget.destinations.length - 4;
      final styles = {
        for (final selected in [false, true])
          selected: _fitLabel(context, labelWidth, selected),
      };
      final painter = TextPainter(
        text: TextSpan(
            text: widget.destinations[widget.currentIndex].label,
            style: theme.textTheme.bodyMedium!.merge(styles[true])),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      )..layout(maxWidth: labelWidth);
      final labelHeight = painter.height +
          (navTheme.labelPadding ?? const EdgeInsets.only(top: 4)).vertical;
      painter.dispose();
      final height = (navTheme.height ?? 80) + (widget.isTeacher ? 12 : 0);
      final indicatorTop = (height - 32 - labelHeight) / 2;
      return AnimatedBuilder(
          animation: _selection,
          builder: (context, child) {
            final progress = Curves.easeOutCubic.transform(_selection.value);
            final activeColor = Color.lerp(
                AppColors.muted, theme.colorScheme.primary, progress)!;
            return Material(
              color: navTheme.backgroundColor ??
                  theme.colorScheme.surfaceContainer,
              shadowColor: navTheme.shadowColor ?? Colors.transparent,
              surfaceTintColor: navTheme.surfaceTintColor ?? Colors.transparent,
              elevation: navTheme.elevation ?? 0,
              child: Stack(children: [
                Positioned.fill(child: IgnorePointer(child: ExcludeSemantics(
                  child: SafeArea(
                      child: LayoutBuilder(builder: (context, safeConstraints) {
                    final slotWidth =
                        safeConstraints.maxWidth / widget.destinations.length;
                    final width = slotWidth.clamp(0.0, 64.0);
                    final index =
                        Directionality.of(context) == TextDirection.rtl
                            ? widget.destinations.length - 1 - _position
                            : _position;
                    return Stack(children: [
                      Positioned(
                        left: (index + .5) * slotWidth - width / 2,
                        top: indicatorTop,
                        width: width,
                        height: 32,
                        child: DecoratedBox(
                          key: const ValueKey('nav-sliding-indicator'),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      )
                    ]);
                  })),
                ))),
                NavigationBar(
                  height: height,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  animationDuration: _reduceMotion ? Duration.zero : _duration,
                  indicatorColor: Colors.transparent,
                  labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                      styles[states.contains(WidgetState.selected)]!.copyWith(
                          color: states.contains(WidgetState.selected)
                              ? activeColor
                              : AppColors.muted)),
                  selectedIndex: widget.currentIndex,
                  onDestinationSelected: (index) {
                    _animateTo(index);
                    GoRouter.maybeOf(context)?.go(widget.routes[index]);
                  },
                  destinations: [
                    for (final destination in widget.destinations)
                      NavigationDestination(
                        icon: IconTheme.merge(
                            data: const IconThemeData(color: AppColors.muted),
                            child: destination.icon),
                        selectedIcon: Transform.scale(
                          scale: .96 + .04 * progress,
                          child: IconTheme.merge(
                              data: IconThemeData(color: activeColor),
                              child:
                                  destination.selectedIcon ?? destination.icon),
                        ),
                        label: destination.label,
                      ),
                  ],
                ),
              ]),
            );
          });
    });
  }

  TextStyle _fitLabel(BuildContext context, double width, bool selected) {
    final states = <WidgetState>{if (selected) WidgetState.selected};
    final style =
        (NavigationBarTheme.of(context).labelTextStyle?.resolve(states) ??
                Theme.of(context).textTheme.labelSmall!)
            .copyWith(letterSpacing: 0);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    var widest = 0.0;
    for (final destination in widget.destinations) {
      final painter = TextPainter(
        text: TextSpan(text: destination.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width =
          widget.isTeacher ? painter.minIntrinsicWidth : painter.width;
      if (width > widest) widest = width;
      painter.dispose();
    }
    final fit = (width / widest).clamp(0.0, 1.0);
    return style.copyWith(fontSize: style.fontSize! * fit);
  }
}

class _NavTravel {
  _NavTravel(this.position);

  double position;
  Object? owner;
}
