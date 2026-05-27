# Guia de Implementação UI/UX - UniConnect

## 🛠️ Componentes e Utilidades Recomendadas

### 1. Loading State Component

```dart
// lib/shared/widgets/loading_state.dart

class LoadingState<T> extends StatelessWidget {
  const LoadingState({
    required this.asyncValue,
    required this.onLoading,
    required this.onData,
    this.onError,
    this.retryCallback,
    this.key,
  }) : super(key: key);

  final AsyncValue<T> asyncValue;
  final Widget Function() onLoading;
  final Widget Function(T data) onData;
  final Widget Function(Object error, StackTrace stack)? onError;
  final VoidCallback? retryCallback;
  final Key? key;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: onData,
      loading: onLoading,
      error: (error, stack) => onError?.call(error, stack) ?? 
        ErrorStateWidget(
          error: error.toString(),
          onRetry: retryCallback,
        ),
    );
  }
}

// Uso:
LoadingState(
  asyncValue: ref.watch(activitiesProvider),
  onLoading: () => const ActivityCardSkeleton(),
  onData: (activities) => ActivityList(activities: activities),
  retryCallback: () => ref.refresh(activitiesProvider),
)
```

### 2. Error Handling Component

```dart
// lib/shared/widgets/error_state_widget.dart

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    required this.error,
    required this.onRetry,
    this.title = 'Algo deu errado',
  });

  final String error;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3. Empty State Component

```dart
// lib/shared/widgets/empty_state_widget.dart

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
              textAlign: TextAlign.center,
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: action,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### 4. Skeleton Loader

```dart
// lib/shared/widgets/skeleton_loader.dart

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({required this.child});
  final Widget child;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          stops: [
            _controller.value - 0.3,
            _controller.value,
            _controller.value + 0.3,
          ],
          transform: GradientRotation(_controller.value * 2 * 3.14159),
        ).createShader(bounds);
      },
      child: Container(
        color: Colors.grey[300],
        child: child,
      ),
    );
  }
}

// Componente para card skeleton:
class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 16,
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 12,
              width: double.infinity,
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 12,
              width: 200,
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 📝 Melhorias por Página

### Dashboard - Reducer de Informação

**ANTES:**
```dart
ListView(
  padding: const EdgeInsets.all(AppSpacing.md),
  children: [
    // Hero card
    // Academic snapshot
    // Quadro de urgências (todos os críticos)
    // Timeline de prazos (4 itens)
    // Atividades pendentes (3 itens)
  ],
)
```

**DEPOIS - Com Tabs:**
```dart
// lib/features/student/presentation/student_dashboard_page.dart

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final activities = ref.watch(activitiesProvider);
    final criticalActivities = activities
        .where((activity) => activity.priority == ActivityPriority.critical)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        bottomNavigationBar: const UniBottomNav(currentIndex: 0),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _HeroCard(user: user, criticalCount: criticalActivities.length),
              const SizedBox(height: AppSpacing.lg),
              const _AcademicSnapshot(),
              const SizedBox(height: AppSpacing.lg),
              
              // Tab bar
              TabBar(
                tabs: [
                  Tab(text: 'Críticas (${criticalActivities.length})'),
                  Tab(text: 'Próximas'),
                ],
              ),
              SizedBox(
                height: 300,
                child: TabBarView(
                  children: [
                    // Tab 1: Críticas
                    criticalActivities.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.check_circle,
                            title: 'Nenhuma urgência!',
                            subtitle: 'Você está em dia com as atividades críticas',
                          )
                        : ListView.builder(
                            itemCount: criticalActivities.length,
                            itemBuilder: (context, index) => ActivityCard(
                              activity: criticalActivities[index],
                              onTap: () => context.push('/atividades/${criticalActivities[index].id}'),
                            ),
                          ),
                    
                    // Tab 2: Próximas
                    ListView.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) => _TimelineItem(
                        activity: activities[index],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.activities),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Ver todas as atividades'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.user, required this.criticalCount});
  
  final AppUser? user;
  final int criticalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bem-vindo,',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: .7),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            user?.name.split(' ').first ?? 'Aluno',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (criticalCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$criticalCount atividade(s) crítica(s)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

### Activities Page - Com Filtro e Busca

```dart
// lib/features/activities/presentation/activities_page.dart

class ActivitiesPage extends ConsumerStatefulWidget {
  const ActivitiesPage({super.key});

  @override
  ConsumerState<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<ActivitiesPage> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allActivities = ref.watch(activitiesProvider);
    
    // Filtrar atividades por busca
    final filteredActivities = allActivities
        .where((activity) =>
            activity.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            activity.subject.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.studentDashboard),
        title: const Text('Atividades'),
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(activitiesProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Campo de busca
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar atividades...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Info card
            AppCard(
              backgroundColor: AppColors.primarySoft,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Total: ${filteredActivities.length} atividade(s)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Groups
            _ActivityGroup(
              title: 'Críticas',
              subtitle: 'Exigem ação imediata',
              count: filteredActivities
                  .where((a) => a.priority == ActivityPriority.critical)
                  .length,
              activities: filteredActivities
                  .where((a) => a.priority == ActivityPriority.critical)
                  .toList(),
            ),
            _ActivityGroup(
              title: 'Prioridade média',
              subtitle: 'Importantes, mas com respiro',
              count: filteredActivities
                  .where((a) => a.priority == ActivityPriority.medium)
                  .length,
              activities: filteredActivities
                  .where((a) => a.priority == ActivityPriority.medium)
                  .toList(),
            ),
            _ActivityGroup(
              title: 'Baixa prioridade',
              subtitle: 'Acompanhar sem interromper seu foco',
              count: filteredActivities
                  .where((a) => a.priority == ActivityPriority.low)
                  .length,
              activities: filteredActivities
                  .where((a) => a.priority == ActivityPriority.low)
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityGroup extends StatelessWidget {
  const _ActivityGroup({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.activities,
  });

  final String title;
  final String subtitle;
  final int count;
  final List<AcademicActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '$title ($count)',
          subtitle: subtitle,
        ),
        ...activities.map(
          (activity) => ActivityCard(
            activity: activity,
            onTap: () => context.push('/atividades/${activity.id}'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
```

### Profile Page - Confirmação de Logout

```dart
// lib/features/profile/presentation/profile_page.dart

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você será desconectado e voltará à tela de login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
              context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.studentDashboard),
        title: const Text('Perfil'),
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 4),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const AppBackAction(fallbackRoute: AppRoutes.studentDashboard),
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 34),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Usuário',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        user?.email ?? 'email@uni.com',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                _ProfileInfo(
                  label: 'Curso',
                  value: user?.course ?? 'Engenharia de Software',
                ),
                const Divider(height: AppSpacing.lg),
                _ProfileInfo(
                  label: 'Matrícula',
                  value: user?.registration ?? '2024021845',
                ),
                const Divider(height: AppSpacing.lg),
                _ProfileInfo(
                  label: 'Semestre',
                  value: '${user?.semester ?? 4}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implementar settings
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Configurações'),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: () => _handleLogout(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
```

---

## 🎯 Checklist de Implementação

### Fase 1: Estados de Carregamento (2-3 dias)
- [ ] Criar `LoadingState` component
- [ ] Criar `SkeletonLoader` component
- [ ] Criar `EmptyStateWidget` component
- [ ] Integrar em `activitiesProvider`
- [ ] Integrar em `gradesProvider`

### Fase 2: Melhorias de Navegação (3-4 dias)
- [ ] Adicionar confirmação de logout
- [ ] Adicionar pull-to-refresh
- [ ] Melhorar AppBackButton visibilidade
- [ ] Testar navegação em todos os fluxos

### Fase 3: Filtros e Busca (4-5 dias)
- [ ] Campo de busca em Activities
- [ ] Filtro por prioridade
- [ ] Filtro por disciplina
- [ ] Ordenação customizável

### Fase 4: UI Refinement (3-4 dias)
- [ ] Reorganizar Dashboard com tabs
- [ ] Melhorar Profile page
- [ ] Adicionar tooltips
- [ ] Teste de acessibilidade

### Fase 5: Polish (2-3 dias)
- [ ] Animações suaves
- [ ] Gestos (swipe back)
- [ ] Dark mode (opcional)
- [ ] Testes finais

---

**Total Estimado:** 2-3 semanas para implementação completa

