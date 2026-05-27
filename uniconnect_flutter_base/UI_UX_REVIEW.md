# Revisão UI/UX - UniConnect

## 📋 Executivo

Análise completa do aplicativo mobile UniConnect baseada nas **10 Heurísticas de Usabilidade de Nielsen** e princípios de design moderno. O projeto apresenta uma base visual sólida com Material Design 3, mas há oportunidades significativas para otimizar fluxos, hierarquia e acessibilidade.

---

## 🎯 Análise por Heurísticas de Nielsen

### 1. **Visibilidade do Status do Sistema** ⚠️ MODERADO
**Status:** Parcialmente atendido

**Pontos Positivos:**
- Dashboard mostra status claro: GPA, semestre, urgências (números visíveis)
- Indicador de progresso visual (72% das atividades encaminhadas)
- Status das disciplinas ("Aprovado", "Reprovado") com contexto

**Problemas:**
- ❌ Sem feedback visual ao carregar dados (sem skeleton, shimmer ou spinner)
- ❌ Sem confirmação ao enviar formulários
- ❌ Sem indicação de sincronização de dados em tempo real
- ❌ Navegação não indica qual aba está ativa além do highlight

**Recomendações:**
```dart
// Adicionar estados de carregamento
if (activities.isLoading) {
  return const LoadingCardsList(); // Skeleton loading
}
if (activities.hasError) {
  return ErrorWidget(error: activities.error);
}
```

---

### 2. **Correspondência entre Sistema e Mundo Real** ✅ BOM

**Pontos Positivos:**
- Linguagem contextualizada ao domínio acadêmico
- Termos naturais: "Quadro de urgências", "Coeficiente de rendimento"
- Estrutura familiar: GPA, disciplinas, notas (P1, P2, Trabalho)
- Cores intuitivas para prioridades (vermelho=crítico, amarelo=médio, verde=baixo)

**Problemas:**
- ⚠️ Rótulo "Atividades pendentes" é ambíguo (pode ser completas ou incompletas)
- ⚠️ "Timeline de prazos" não é uma timeline visual real
- ⚠️ Ícone de "auto_awesome" no dashboard não relaciona com conteúdo

**Recomendações:**
```dart
// Renomear para maior clareza
"Atividades que ainda precisam de decisão" → "Atividades em andamento"
"Timeline de prazos" → "Próximos prazos" 

// Remover ícone sem significado
// Ou trocar por ícone relacionado: trending_up (performance)
```

---

### 3. **Controle e Liberdade do Usuário** ⚠️ CRÍTICO

**Problemas Principais:**
- ❌ Sem botão voltar visível em todas as páginas (apenas AppBackButton discreto)
- ❌ Sem histórico de navegação entre dashboards
- ❌ Ações críticas (logout) sem confirmação
- ❌ Sem undo/redo em formulários
- ❌ Paginação não é clara (`.take()` e `.skip()` ocultam conteúdo)

**Recomendações:**
```dart
// Adicionar confirmação de logout
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Sair da conta?'),
    content: const Text('Você será desconectado'),
    actions: [
      TextButton(onPressed: () => pop(), child: const Text('Cancelar')),
      ElevatedButton(onPressed: () => logout(), child: const Text('Sair')),
    ],
  ),
);

// Adicionar botão "Ver mais" para atividades ocultas
if (activities.length > 4) {
  GestureDetector(
    onTap: () => context.push(AppRoutes.activities),
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Text('Ver todas as 8 atividades', 
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
```

---

### 4. **Consistência e Padrões** ✅ BOM

**Pontos Positivos:**
- Design system bem estabelecido (AppColors, AppSpacing, AppTheme)
- Componentes reutilizáveis (AppCard, SectionHeader, ActivityCard)
- Tokens de spacing consistentes (md, lg)
- AppBar e BottomNav em padrão Material Design 3

**Problemas:**
- ⚠️ Duplicação: `AppBackButton` AND `AppBackAction` no mesmo arquivo
- ⚠️ Padding inconsistente: alguns widgets usam 18, outros usam AppSpacing.md
- ⚠️ Espaçamento entre seções variável (18, 12, 14)

**Recomendações:**
```dart
// Consolidar constantes de espaçamento
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

// Usar em toda parte
ListView(
  padding: const EdgeInsets.all(AppSpacing.lg),
  children: [...],
)
```

---

### 5. **Prevenção de Erros** ⚠️ MODERADO

**Problemas:**
- ❌ Sem validação visível em formulários (login, criar atividade)
- ❌ Sem tratamento de campos vazios
- ❌ Sem feedback de erro quando dados falham ao carregar
- ❌ Divisão por zero potencial: `gpa / subjects.length` sem verificação

**Recomendações:**
```dart
// Validação no login
if (email.isEmpty || !email.contains('@')) {
  showError('Email inválido');
  return;
}

// Tratamento seguro de GPA
final gpa = subjects.isEmpty 
  ? 0.0 
  : subjects.map((s) => s.finalAverage).reduce((a, b) => a + b) / subjects.length;
```

---

### 6. **Reconhecimento ao Invés de Lembrança** ✅ BOM

**Pontos Positivos:**
- Ícones de ação clara (dashboard, checklist, chat, school, person)
- Cores de status fácil reconhecimento (vermelho=crítico)
- Seções com headers descritivos + subtítulos explicativos

**Problemas:**
- ⚠️ Labels de prioridade ("Críticas", "Prioridade média") requerem leitura
- ⚠️ Sem ícones visuais para as seções de urgência

**Recomendações:**
```dart
// Adicionar ícones visuais para prioridade
Icon(
  priority == ActivityPriority.critical ? Icons.error : Icons.info,
  color: priorityColor,
)
```

---

### 7. **Flexibilidade e Eficiência de Uso** ⚠️ CRÍTICO

**Problemas:**
- ❌ Sem busca/filtro em "Atividades"
- ❌ Sem ordenação customizável (por data, prioridade)
- ❌ Sem atalhos de teclado
- ❌ Sem gestos (swipe para voltar, pull-to-refresh)
- ❌ Navegação profunda limitada (sem URLs deep-linkable)

**Recomendações:**
```dart
// Adicionar filtros e buscas
SearchBar(
  hintText: 'Buscar atividades...',
  onChanged: (value) => filterActivities(value),
)

// Adicionar gestos
RefreshIndicator(
  onRefresh: () => ref.refresh(activitiesProvider),
  child: ListView(...),
)
```

---

### 8. **Design Estético e Minimalista** ✅ EXCELENTE

**Pontos Positivos:**
- Paleta de cores bem definida (azul primário, laranja secundário)
- Tipografia clara (Inter, pesos bem distribuídos)
- Espaçamento generoso (breathing room)
- Ícones Material Design consistentes
- Sem clutter visual desnecessário

**Pequenos Ajustes:**
- ⚠️ Card no dashboard com ícone "auto_awesome" sem propósito
- ⚠️ Muitas seções no dashboard (considerar tabs ou collapse)

---

### 9. **Ajuda e Documentação** ❌ AUSENTE

**Problemas:**
- ❌ Sem tooltips explicativos
- ❌ Sem onboarding para novo usuário
- ❌ Sem ajuda em contexto
- ❌ Sem FAQ ou suporte

**Recomendações:**
```dart
// Adicionar tooltip
Tooltip(
  message: 'Atividades que exigem ação nos próximos 3 dias',
  child: Icon(Icons.info_outline),
)

// Adicionar onboarding
OnboardingOverlay(
  title: 'Quadro de Urgências',
  description: 'Veja as atividades críticas que precisam sua atenção',
)
```

---

### 10. **Recuperação de Erros** ⚠️ MODERADO

**Problemas:**
- ❌ Sem mensagens de erro amigáveis
- ❌ Sem opção de retry para falhas de rede
- ❌ Sem salvamento de draft em formulários

**Recomendações:**
```dart
// Erro tratado com graciosidade
catch (e) {
  showSnackBar(
    'Erro ao carregar atividades',
    action: SnackBarAction(
      label: 'Tentar novamente',
      onPressed: () => ref.refresh(activitiesProvider),
    ),
  );
}
```

---

## 📊 Análise de Informação (IA) - Arquitetura da Informação

### Dashboard do Aluno - ANÁLISE CRÍTICA

**Hierarquia Visual Encontrada:**
1. Hero card com saudação (top)
2. Card de métricas (GPA, semestre)
3. **Seções desorganizadas:**
   - Quadro de urgências (críticas)
   - Timeline de prazos
   - Atividades pendentes

**Problema:** Muita informação acumulada sem priorização clara

**Solução Proposta - Reorganizar por Frequência de Uso:**
```
┌─────────────────────────────────────┐
│ TOPO: Saudação + Status Crítico     │ (O que preciso fazer AGORA)
├─────────────────────────────────────┤
│ Atividades Críticas (Lista)         │ (Ação imediata)
├─────────────────────────────────────┤
│ TABS: [Hoje] [Semana] [Mês]         │ (Próximas ações)
│ Timeline compacta                   │
├─────────────────────────────────────┤
│ [Ver mais atividades →]             │ (Deep dive)
├─────────────────────────────────────┤
│ Desempenho Acadêmico (GPA, chart)  │ (Contexto)
└─────────────────────────────────────┘
```

---

## 🎨 Recomendações Específicas por Página

### 1️⃣ Login Page
**Status:** ❌ Sem avaliação (arquivo não revisado)
- Adicionar validação visual inline
- Mostrar requisitos de senha
- Adicionar opção "Lembrar-me"

### 2️⃣ Student Dashboard
**Problemas:** Muitas seções, priorização unclear
- Limitar a 3-4 seções principais
- Usar tabs para "Timeline" vs "Atividades"
- Adicionar CTA (Call-to-Action) claro

### 3️⃣ Activities Page
**Bom:** Agrupamento por prioridade é intuitivo
- Adicionar busca/filtro
- Adicionar badge de contagem por grupo
- Adicionar pull-to-refresh

### 4️⃣ Grades Page
**Bom:** Visualização clara de notas
- Considerar gráfico de tendência (linha)
- Adicionar simulador melhorado
- Mostrar comparação com média da turma

### 5️⃣ Profile Page
**Problemas:** Muito simples, botões grandes demais
- Adicionar seção de preferências
- Adicionar histórico acadêmico
- Reorganizar botões com menos espaço

---

## 🚀 Prioridade de Implementação

### 🔴 CRÍTICA (Semana 1)
- [ ] Adicionar estados de carregamento (skeleton/shimmer)
- [ ] Confirmação antes de logout
- [ ] Tratamento de erros com retry
- [ ] Validação de formulários

### 🟡 ALTA (Semana 2-3)
- [ ] Pull-to-refresh em listas
- [ ] Busca/filtro em atividades
- [ ] Reorganizar dashboard (menos seções)
- [ ] Tooltips explicativos

### 🟢 MÉDIA (Semana 4+)
- [ ] Onboarding para novo usuário
- [ ] Gráficos de tendência
- [ ] Gestos (swipe back)
- [ ] Deep linking URLs

---

## 📱 Checklist de Acessibilidade

- [ ] Contraste de cores: WCAG AA (4.5:1 mínimo para texto)
- [ ] Tamanho mínimo de toque: 48dp x 48dp
- [ ] Sem dependência apenas de cor (usar também ícones)
- [ ] Suporte a leitores de tela
- [ ] Estrutura semântica de hierarquia (h1, h2, h3...)

**Código para verificar contraste:**
```dart
// Verificar contrastes no AppColors
final contrastPrimary = calculateContrast(AppColors.primary, Colors.white); // ~8.5:1 ✅
final contrastMuted = calculateContrast(AppColors.muted, AppColors.background); // ~3.2:1 ⚠️
```

---

## 💡 Padrões UX Recomendados

### Empty States
```dart
if (activities.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, size: 64, color: AppColors.success),
        SizedBox(height: 16),
        Text('Nenhuma atividade crítica'),
        Text('Você está em dia! 🎉', style: TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}
```

### Error Boundaries
```dart
ref.watch(activitiesProvider).whenData((data) {
  return ActivityList(activities: data);
}).whenError((error, stack) {
  return ErrorWidget(error: error, onRetry: () => ref.refresh(activitiesProvider));
});
```

### Loading States
```dart
// Usar ShimmerEffect ou Skeleton loaders
Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: ActivityCardSkeleton(),
)
```

---

## 📈 Métricas de Sucesso

- [ ] **Tempo na tarefa:** < 3 cliques para acessar atividade crítica
- [ ] **Taxa de erro:** < 2% de usuários com erro ao navegar
- [ ] **Satisfação:** Score SUS > 70
- [ ] **Retenção:** > 60% usuarios retornam em 7 dias

---

## 🔗 Referências

- **Nielsen's 10 Usability Heuristics**: https://www.nngroup.com/articles/ten-usability-heuristics/
- **Material Design 3**: https://m3.material.io/
- **Flutter Best Practices**: https://flutter.dev/docs/testing/best-practices
- **WCAG 2.1 Accessibility**: https://www.w3.org/WAI/WCAG21/quickref/

---

**Documento atualizado em:** 2026-05-22  
**Revisor:** Claude AI  
**Próxima revisão:** Após implementação das mudanças críticas
