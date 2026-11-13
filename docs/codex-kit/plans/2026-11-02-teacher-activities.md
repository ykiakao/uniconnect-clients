# Atividades docentes — plano de implementação
Objetivo: criar rascunhos e publicá-los por HTTP autenticado no Flutter, sem alterar API/banco.
Direção visual: manter AppHeader, AcademicContent, AppCard, tipografia, cores e espaçamentos existentes. Formulário vertical acessível; lista por oferta com estado e ação de publicação. Sem assets novos.
Contrato: GET offerings (escopo docente servidor, paginação); GET/POST classes/:id/activities; GET/PUT activities/:id; POST activities/:id/publish com expectedVersion=revision. Criação retorna objeto diretamente, lista usa data/meta. Edição confirmada, fora da interface desta tarefa.
1. Testes locais de contrato HTTP antes da implementação.
2. Serviço/modelos docentes isolados, paginação completa, providers com sessão existente.
3. Formulário de rascunho e lista por oferta; publicação individual, bloqueio de duplicidade e recuperação explícita de conflitos, sem retries automáticos de escrita.
4. Testes de widgets/permissões, HTTP, estados pendentes e conflitos; ajustar expectativas obsoletas do protótipo.
5. Revisão, testes pertinentes incluindo regressões de notas, flutter analyze e git diff --check.
Limites: sem entregas, avaliação, comunicação, infraestrutura, serviços remotos ou dependências novas. Preservar diff preexistente de notas.

## Resultado local — 02/11/2026
- Serviço/provider novos: lib/features/teacher/services/teacher_activity_service.dart e lib/features/teacher/providers/teacher_activity_provider.dart.
- Interface: lib/features/teacher/presentation/create_activity_page.dart e teacher_dashboard_page.dart.
- Testes novos: test/teacher_activities_test.dart, teacher_activity_service_test.dart e teacher_activity_provider_test.dart.
- Testes ajustados às ações reais: test/demo_day_test.dart, demo_navigation_test.dart, demo_responsive_test.dart, final_refinement_test.dart, layout_quality_test.dart e synthetic_academic_demo_test.dart. Este último ainda esperava a média removida na primeira tarefa; agora exige a contagem de avaliações.
- flutter test --no-pub --reporter expanded: 156 testes aprovados após a última alteração. Log local: uniconnect_flutter_base/build/teacher-activities-tests.log.
- flutter analyze --no-pub: nenhum problema.
- git diff --check: aprovado.
- Revisão independente: nenhum bloqueador; corrigido desbloqueio de conflito ao selecionar novamente a mesma oferta.
- Capturas locais em build/layout-qa/after, com fixtures/sessão indisponível: conferidos 320px e texto2x; rótulos agora quebram linha.
- Comparação binária dos cinco arquivos de implementação da correção de notas com a cópia validada da tarefa anterior: idênticos.

## Contratos confirmados
- GET /tenants/:slug/offerings?status=active&page=N&limit=100: data/meta; escopo por teaching_assignments ativos aplicado pela API. O seletor não permite IDs livres.
- GET /tenants/:slug/classes/:classId/activities: data/meta, paginação completa, state e revision reais.
- POST na mesma rota: title obrigatório; type padrão assignment, textos opcionais, dueDate ISO com timezone, priority low/medium/high, allowLate boolean, state draft. Resposta direta, sem envelope data.
- GET /tenants/:slug/activities/:id: objeto direto com revision e estado.
- PUT /tenants/:slug/activities/:id: campos parciais sem state; expectedVersion obrigatório para workflow. Contrato confirmado, interface de edição fora desta tarefa.
- POST /tenants/:slug/activities/:id/publish: expectedVersion inteiro igual à revision observada; somente docente atribuído, oferta/período elegíveis e estado draft; resposta publicada com revisão maior. Publicação não é campo da criação.
- Fontes: API activities.routes.ts, activities.workflow.schemas.ts, activities.service.ts, activities.repository.ts, academic-structure.service.ts, academic-structure.repository.ts e função manage_academic_activity na migration 20261026000004 (somente leitura).

## Limitações
Validação offline com HTTP simulado e widgets. Nenhuma comprovação de persistência remota, integração ponta a ponta, permissões do banco instalado ou ambiente compatível. Sem alterações na API/banco/auth/infra, sem migrations e sem acesso a Supabase/VPS. P0.5 permanece NO-GO. Entregas, avaliações, comunicação e edição de atividades não foram integradas. Falhas de escrita exigem conferir a listagem; nenhuma escrita é repetida automaticamente.
