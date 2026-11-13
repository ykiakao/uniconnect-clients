# UniConnect — direção e inspeção para a Demo Day

## Escopo autorizado

Polir as telas existentes de aluno e professor preservando a identidade atual, os contratos HTTP, a autenticação e os providers. O pedido de 28/10/2026 autoriza esta continuidade visual; não há proposta de reformulação. Base: design de consulta de 30/09/2026. Trabalhar somente neste repositório, sem Supabase remoto, commits, push ou deploy.

## Inspeção anterior às alterações

- Árvore de trabalho limpa (`git status --porcelain=v1`). Branch inicial `main`; execução isolada em branch local `demo-day-flutter-polish`, no mesmo repositório.
- Flutter em `uniconnect_flutter_base`; Material 3, Riverpod 3, GoRouter 17, Inter local. Azul #004A99, laranja #F58220, fundo #F4F7FB. Tokens de espaçamento e componentes compartilhados já existem.
- Aluno: login, restauração da sessão, dashboard, atividades com busca/filtro/refresh, detalhes somente leitura, notas com simulador, chat e perfil.
- Professor: dashboard com identidade/instituição/curso opcional; rotas adicionais para criar atividade e lançar notas são protótipos sem integração, sem atalhos no dashboard.
- Login: `ApiAuthService` chama `/auth/login` e `/auth/me`; `AuthController` controla restauração, persistência opcional e logout. Não mudar estes contratos. `computeRedirect` separa perfis, mas precisa cobrir detalhes de atividade com ID concreto.
- `activitiesProvider` consulta `AcademicApiService`: cursos → turmas → atividades; `activityByIdProvider` deriva da lista. `subjectGradesProvider` consulta notas do aluno. `currentUserProvider` e `currentTenantProvider` derivam da sessão.
- Dados fixos sem rótulo: GPA/urgências/cursos do dashboard, progresso/créditos/premiação em notas, mensagens do chat, alunos/notas no protótipo docente e valores de fallback no perfil.
- A API fornece uma nota por atividade; o adaptador legado replica essa nota em P1/P2/trabalho. A UI deve apresentá-la como nota da atividade, sem alegar CR oficial ou aprovação institucional.
- O adaptador de atividades inventa prazo de 30 dias quando a API não fornece data; substituir por ausência explícita. O serviço de autenticação tem fallback legado para instituição; não o alterar, e não exibir esse nome como instituição confirmada quando não houver ID institucional.

## Direção criativa

Três conceitos avaliados dentro da identidade existente:

| Conceito | Tese / composição | Tipografia e cores | Assets / interação | Limite e risco |
| --- | --- | --- | --- | --- |
| Agenda acadêmica (recomendado) | Identidade institucional seguida por próximos prazos reais e atalhos de consulta | Inter; azul para identidade, laranja para atenção | Ícones Material de calendário, disciplina e perfil; toque e refresh existentes | Sem métricas inventadas; risco reduzido usando os providers atuais |
| Portal institucional (conservador) | Identificação e listas informativas sem destaque para agenda | Mesma Inter e paleta, menor contraste de composição | Ícones existentes; navegação atual | Menos expressivo para o aluno, adequado à área docente com poucos dados |
| Caderno de estudos (expressivo) | Linha do tempo visual contínua de entregas | Inter com marcadores laranja e azul | Marcadores de prazo; transições existentes | Maior alteração de layout e risco de demo; fora desta entrega |

Aplicar Agenda acadêmica ao aluno e sua composição informativa ao professor, dentro da direção já solicitada. Em cinco segundos, devem ficar claros o perfil, a instituição confirmada e o próximo passo disponível. Os artefatos visuais são informações acadêmicas reais, prazos e disciplinas; imagens decorativas não ajudam esta consulta e não serão adicionadas.

- Hierarquia: identificação → contexto acadêmico → consulta/agenda → informações auxiliares.
- Preservar Inter, azul e laranja, raios e componentes existentes. Espaçamentos de 8/12/16/24/32 px. Conteúdo com largura máxima em telas grandes.
- A diferenciação vem da agenda por disciplina e da identidade institucional por perfil; sem indicadores genéricos de SaaS, gradientes decorativos ou gráficos fictícios.
- Loading, erro com nova tentativa e ausência de dados são estados distintos. Dados ausentes não valem zero e não provam que o aluno está em dia.
- Professor: identidade, instituição, vínculo quando fornecido, perfil acessível e limite explícito de gestão. Não consultar listas institucionais como se fossem turmas atribuídas ao professor.
- Preservar protótipos existentes com rótulo de demonstração; impedir publicações/envios falsos. Simulador continua local e se identifica como simulação, sem valor oficial.
- Sem animações novas. Controles existentes com nomes acessíveis, teclado no login e alvos de toque Material.

## Aceitação visual e funcional

- Nenhum dado acadêmico fixo apresentado como real; nenhum sucesso de publicação/envio sem API.
- Identidade e instituição presentes nos dois perfis; ausência de vínculo docente explicada.
- Aluno navega por início → atividades → detalhes → notas → perfil; professor → perfil → retorno → logout.
- Carregamento, erro recuperável e vazio revisados; zero é uma nota válida.
- Checar larguras móveis de 320/375/430 e layouts 768/1024/1440, além de texto ampliado.
- Rodar dependências, análise, testes e build web. Login real só será afirmado se exercitado contra a API disponível; testes usam fakes apenas na suíte.

Próxima skill: `interface-craft`, após plano executável.
