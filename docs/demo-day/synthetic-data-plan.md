# EduKMais — plano da base acadêmica sintética

## Escopo e plano executável

Fase 1 exclusivamente documental, autorizada pelo pedido de 28/10/2026. Design: arquivo relacional independente, com identificadores sintéticos, instituição EduKMais, quatro períodos e cinco disciplinas atuais. Não há importação automática, integração Flutter ou carga em banco.

Arquivos-alvo: `docs/demo-day/synthetic-academic-data.json` e este plano. Branch: `demo-day-flutter-polish`. As alterações anteriores e o build funcional devem permanecer intactos.

- [x] Localizar conector e resultados locais; inspecionar apenas campos, tipos, contagens e relações, sem reproduzir valores privados.
- [x] Conferir modelos Flutter e adaptador acadêmico existentes.
- [x] Criar JSON inteiramente autoral com quatro períodos, currículo fictício, dez atividades e seis avaliações.
- [x] Validar sintaxe, unicidade, referências, datas, isolamento e preservação dos arquivos existentes.
- [x] Fazer revisão independente dos dois documentos, registrar resultados e encerrar sem integração.

## 1. Arquivos encontrados e proveniência

Caminhos relativos ao workspace `SaaS_UniConnect`, acessados somente para leitura:

| Fonte | Disponibilidade e uso |
| --- | --- |
| `uniconnect-api/packages/uninorte-connector/integrations/uninorte/normalizer.mjs` | Mapeamentos de período, disciplina, atividade, nota e situação; consultado |
| `uniconnect-api/packages/uninorte-connector/types/index.d.mts` | Fachada do pacote e operações acadêmicas; consultado |
| `uniconnect-api/packages/uninorte-connector/README.md` | Documentação disponível; consultada |
| `integrations/uninorte/README.md` | Contratos, organização acadêmica e limites; consultado |
| `docs/codex-kit/reviews/2026-10-25-conector-uninorte.md` | Relatório da Etapa 1; consultado |
| `tests/uninorte-normalizer.test.mjs` | Exemplos sintéticos de null, zero, ausência e situação desconhecida; consultado |
| `saida-portal-aluno/2026-10-26T04-16-35-382Z/json/periodos-letivos.json` | Confirmados oito períodos; inspecionados campos e contagem |
| `saida-portal-aluno/2026-10-26T04-16-35-382Z/json/periodo-atual.json` | Campo `data` e referência a um período da lista; estrutura conferida |
| `saida-portal-aluno/2026-10-26T04-16-35-382Z/json/disciplinas-*.json` | Oito arquivos, cinco registros por arquivo, total de 40 registros; somente estrutura e contagens utilizadas |
| `saida-portal-aluno/2026-10-26T04-16-35-382Z/json/notas-*.json` | Oito boletins JSON e consolidado com oito períodos/40 registros; somente estrutura e contagens utilizadas |
| `saida-portal-aluno/2026-10-26T03-50-56-488Z/pdf/` | Oito arquivos PDF confirmados por enumeração; não abertos, extraídos ou copiados nesta fase |

Existem outras execuções anteriores em `saida-portal-aluno/`, incluindo uma exportação com oito arquivos de disciplinas e outra com quatro PDFs. Não foram somadas como novas disciplinas ou novos períodos. O pacote dentro de `uniconnect-api` contém código e documentação, mas os resultados brutos localizados ficam na saída do explorador na raiz do workspace.

Nenhuma fonte pessoal foi copiada para o cliente. Não foram consultados valores de matrícula, e-mail, CPF, nomes de alunos, autenticação ou conteúdo dos PDFs. As linhas de notas foram examinadas apenas pelo nome e tipo dos campos; seus valores individuais não fundamentam as notas sintéticas.

## 2. Estruturas aproveitadas

- Período com ID próprio e identificador ano/semestre; na coleta, a forma compacta de cinco caracteres é normalizada para `AAAA.S`. O período atual é retornado separadamente e deve pertencer à lista histórica.
- Disciplinas agrupadas por período, com ID da disciplina distinto do ID da oferta, vínculo de turma e referência ao período. A base reduz o histórico para quatro períodos e mantém uma oferta explícita por registro de disciplina, sem reproduzir a grade real.
- Boletim organizado por período e disciplina, com avaliação 1/2, média, exame, média final, faltas e situação. O conector preserva zero, null e ausência e não calcula resultados acadêmicos por dedução.
- Atividades vinculadas à oferta e ao período, com descrição, tipo, disponibilidade e prazos distintos na fonte. Não se presume que uma situação como “Validado” corresponda a entrega ou aprovação.

Foram aproveitados esses padrões de organização, não conteúdos pessoais, notas, nomes de disciplinas coletados, identificadores ou regras de aprovação da instituição original.

## 3. Informações não utilizadas ou não comprovadas

Não se verificaram conteúdos dos PDFs, notas individuais, pesos institucionais, critérios de aprovação, GPA, ranking ou progresso de curso. A estrutura disponível não autoriza converter média final do boletim em nota de uma atividade específica. Nomes e atribuições de docentes não foram obtidos da coleta para esta finalidade.

Matrícula e semestre do usuário autenticado permanecem ausentes quando não fornecidos pela API atual. O ordinal curricular desta base fictícia não comprova o semestre de um usuário real. Não há aluno sintético, credenciais ou conta de acesso neste arquivo.

## 4. Esquema e criação autoral

O JSON usa `schemaVersion: "1.0.0"` e `metadata.synthetic: true`. Todos os nomes, textos, identificadores e notas foram redigidos para esta demonstração, sem transformar registros pessoais. Os docentes se chamam explicitamente “Docente Demo 01” a “Docente Demo 05”, sem e-mails ou dados de contato.

| Coleção/campo | Contrato documental |
| --- | --- |
| `institution` | `id`, `slug`, `name`, `displayName`; o slug `edukmais` é somente a identidade institucional solicitada, não uma autorização para gravar no tenant |
| `courses` | `id`, `institutionId`, `name`, `currentPeriodId` |
| `periods` | `id`, `courseId`, `label`, `calendarSemester`, `curricularOrdinal`, `startsOn`, `endsOn`, `isCurrent` |
| `teachers` | `id`, `institutionId`, `displayName`; personas estritamente fictícias |
| `subjects` | `id`, `courseId`, `periodId`, `offeringId`, `code`, `name`, `teacherId`; uma oferta por registro. `offeringId` é outro identificador sintético único |
| `activities` | `id`, `subjectId`, `offeringId`, `periodId`, `teacherId`, `title`, `description`, `dueDate`, `priority`, `status`, `criteria`, `attachments` |
| `evaluations` | `id`, `subjectId`, `periodId`, `activityId` opcional/null, `code`, `title`, `grade`, `maxGrade`, `feedback`, `assessedAt` |

Todos os IDs/ofertas são strings com prefixo `demo-edukmais-`, distintos de IDs da API. Não são UUIDs nem payloads de escrita. Relações usam esses IDs, nunca nomes ou códigos abreviados. `code` é um rótulo único na respectiva coleção. Notas são números decimais de 0 a 10; zero é válido, ausência não deve virar zero. Nenhuma média oficial, aprovação, classificação ou porcentagem de conclusão foi criada.

`priority` admite `critical`, `medium`, `low`; `status` admite `pending`, `inProgress`, `done`, correspondendo aos enums locais. São escolhas autorais explícitas da fixture, não inferências a partir de prazo ou nota. `criteria` e `attachments` são listas de strings; não há anexos pessoais nem links externos. Os períodos usam datas civis `AAAA-MM-DD`; prazos e avaliações usam ISO 8601 com offset `-05:00`.

## 5. Quantidades planejadas

| Categoria | Quantidade |
| --- | --- |
| Instituição | 1 — EduKMais — Ambiente de demonstração do UniConnect |
| Curso | 1 — Engenharia de Software |
| Períodos | 4: 2025.1, 2025.2, 2026.1 e 2026.2 |
| Disciplinas/ofertas | 14: três em cada período anterior e cinco no atual |
| Docentes fictícios | 5 |
| Atividades | 10, todas no período atual |
| Avaliações | 6: cinco atuais e uma histórica; quatro com atividade correspondente e duas sem atividade |

As disciplinas atuais são Engenharia de Requisitos, Banco de Dados, Arquitetura de Software, Engenharia de Software e Testes de Software. As nove anteriores formam uma sequência fictícia de fundamentos, programação e desenvolvimento; não representam uma transcrição curricular da Uninorte.

## 6. Distribuição dos prazos

Referência fixa: **28/10/2026 às 19h no Acre**, `2026-10-28T19:00:00-05:00`, fuso IANA `America/Rio_Branco` (equivale a 29/10/2026 00h UTC). Esta é uma fotografia para a apresentação, não um conjunto de datas móveis.

| Categoria no instante de referência | Quantidade | Prazos locais |
| --- | --- | --- |
| Encerrados | 4 | 20, 22, 24 e 26/10/2026 às 18h |
| Futuros em até 24h | 2 | 28/10 às 22h (+3h) e 29/10 às 18h (+23h) |
| Futuros após 24h | 2 | 30/10 às 23h e 10/11 às 18h |
| Sem prazo | 2 | `dueDate: null` |

Total: quatro futuros, quatro encerrados e dois ausentes. Das atividades futuras, duas são críticas, uma média e uma baixa no instante de referência. As seis avaliações já ocorreram antes da referência; as quatro vinculadas pertencem às atividades encerradas. Avaliações sem atividade representam registros demonstrativos independentes, não relações inventadas para boletins reais.

## 7. Compatibilidade com o Flutter atual

Inspeção restrita aos modelos `AcademicActivity`, `SubjectGrade`, `AppUser`, ao serviço `AcademicApiService` e aos usos de período/disciplinas/notas nas telas já inspecionadas. Nenhum desses arquivos foi alterado nesta fase.

| Base documental | Mapeamento futuro e limite atual |
| --- | --- |
| `activities.id/title/description/dueDate` | Compatíveis com `AcademicActivity`; converter ISO para DateTime, mantendo offset e exibição local |
| `subjectId`, `teacherId` | Resolver para `subject` e `teacher` textuais. O modelo local não possui essas chaves nem `periodId`/`offeringId`; mantê-las na camada demonstrativa e filtrar período explicitamente |
| `priority`, `status`, `criteria`, `attachments` | Mapear enums pelo nome; listas já compatíveis. `dueLabel` deve ser gerado a partir do prazo e do relógio escolhido, sem salvar um texto relativo que fique desatualizado |
| Período e curso | Não há modelo público correspondente no Flutter. `_ApiCourse` e `_ApiClass` são auxiliares privados do serviço; uma turma retornada hoje fornece o texto de `subject`, não um ID de disciplina curricular |
| `evaluations.grade/feedback/activityId` | `SubjectGrade` aceita feedback e atividade opcional. Para manter a apresentação atual de nota de atividade, preencher `p1`, `p2` e `work` com a mesma nota, como o serviço atual faz; isso não representa três avaliações reais nem pesos do boletim |
| `evaluations.title/code` | Mapear para `SubjectGrade.subject/code`; `subject` hoje representa título da avaliação. Usar o código documental explícito para evitar colisão da função atual que usa os primeiros seis caracteres do ID: todos os IDs de demo compartilham prefixo |
| Avaliação sem atividade | Manter `activityId: null`; não criar atividade artificial. A tela atual não consegue mostrar a disciplina contextual sem uma atividade correspondente; a relação continua no JSON e exige decisão explícita na futura integração |
| Avaliação histórica | Excluir do acompanhamento do período atual por filtro explícito. Sem esse filtro, a média simples do dashboard e quadro de notas misturaria períodos |
| Identificação, instituição e perfil | A sessão real continua responsável por `AppUser` e `TenantContext`; não substituir identidade, matrícula ou e-mail pelo arquivo. `registration`, `semester` e `course` são opcionais no perfil e não devem ser preenchidos silenciosamente |

O adaptador HTTP atual não consome este JSON. Ele busca cursos → turmas → atividades, atribui professor genérico/status pending e calcula prioridade pela data; notas vêm de endpoint próprio. Portanto, o arquivo não pode ser colocado como resposta da API sem adaptação. Nenhum contrato ou endpoint foi alterado.

## 8. Riscos da futura integração

1. Mistura silenciosa de fontes: demonstrativos devem formar um conjunto separado, com identificação persistente, sem combinar com respostas reais.
2. Tempo: após a Demo Day, prazos deixam de ter a mesma distribuição; documentar a fotografia. Se houver relógio de apresentação fixo, exibi-lo explicitamente e não alterar datas ou relógio do modo normal.
3. Offset: testar conversão para Acre, sobretudo porque a referência local já corresponde ao dia seguinte em UTC. Nunca remover o offset.
4. Contratos: períodos, ofertas e disciplina por ID não têm representação completa nas telas atuais; a base não é seed de backend nem resolve lacunas de gestão docente.
5. Códigos: abreviar IDs pelo prefixo produziria colisões visuais; usar os códigos explícitos.
6. Situação: não inferir aprovação, entrega ou pendência apenas de prazo/nota; não apresentar a média simples como coeficiente oficial.
7. Publicação: manter controles não integrados bloqueados, mesmo com dados sintéticos preenchidos.

## 9. Ativação explícita proposta — não implementada

Em uma próxima fase autorizada, estudar um modo demonstrativo opt-in, desligado por padrão, com indicação permanente **“Dados sintéticos de demonstração — EduKMais”** em todas as telas afetadas. O login e a sessão devem continuar no fluxo atual. A escolha de fonte acadêmica precisa ser única por sessão de apresentação, com armazenamento/cache separados, sem fallback silencioso após erro de API e sem POST/PUT/PATCH/DELETE.

O arquivo atualmente está em `docs/`, fora dos assets Flutter. Não há flag, provider, loader, rota, botão ou configuração implementada. Uma flag futura é apenas proposta e precisa de implementação e validação próprias; não existe comando de ativação nesta fase.

## 10. Retorno ao modo normal

Hoje o modo normal permanece integralmente ativo; não há nada para desativar. Na futura integração, desligar a opção demonstrativa deve descartar somente o cache acadêmico sintético e recarregar os endpoints normais, mantendo autenticação e dados remotos. Nenhuma exclusão, migração, restauração de banco ou sincronização de registros sintéticos deverá ser necessária.

## Validação desta fase

Verificação local em 28/10/2026, usando Python da máquina, sem bibliotecas adicionais:

| Verificação | Resultado |
| --- | --- |
| Parsing JSON, chaves duplicadas e UTF-8 | Aprovados; sem chaves repetidas ou caracteres de substituição |
| Identificadores | 55 strings únicas no namespace sintético: 41 entidades e 14 ofertas |
| Relações | Curso/instituição, período/curso, disciplina/período/docente, atividade/oferta/disciplina e avaliação/atividade conferidos |
| Quantidades | 1 instituição, 1 curso, 4 períodos, 14 disciplinas, 5 docentes, 10 atividades e 6 avaliações |
| Distribuição | 4 prazos encerrados, 2 futuros até 24h, 2 futuros após 24h e 2 ausentes, na referência das 19h Acre |
| Datas | Offset -05:00, referência em UTC, datas dentro dos respectivos períodos e avaliações anteriores à referência; avaliações vinculadas posteriores ao prazo de sua atividade |
| Avaliações | Notas finitas entre 0 e 10, códigos únicos, 4 vínculos com atividade e 2 null; 5 atuais e 1 histórica |
| Enums e listas | Prioridades/status compatíveis com enums locais, critérios textuais e anexos vazios |
| Privacidade | Conteúdo autoral revisado; busca sem campos pessoais/de autenticação, e-mails, URLs externas ou anexos. As notas não foram copiadas das fontes |
| Preservação | Hashes de 502 arquivos existentes comparados antes/depois, incluindo fontes dos dois repositórios e `build/web/index.html`/`main.dart.js`: nenhuma mudança. Somente os dois documentos desta fase foram adicionados |
| Git | Branch `demo-day-flutter-polish`, HEAD `3c70edc` preservado, sem staged files; `git diff --check` sem erros |
| Revisão independente | Dois documentos revisados, incluindo parsing/relações e compatibilidade; nenhum finding relevante pendente |

Para repetir a conferência sintática, na raiz de `uniconnect-clients`:

```powershell
python -m json.tool docs/demo-day/synthetic-academic-data.json > $null
```

As verificações relacionais foram executadas em memória com assertions sobre IDs, referências, enums, intervalos de notas, datas ISO e contagens; não foi criado script funcional no aplicativo. A checagem automatizada de campos sensíveis complementa a autoria e revisão manual, não é uma ferramenta geral de anonimização.

Não foram executados testes Flutter ou build nesta fase, conforme o escopo documental. Não houve execução do conector, SQL, migrations, chamadas externas, Supabase, commit, push ou deploy. As 84 aprovações Flutter e o build são evidências da rodada anterior; não foram reapresentados como testes novos.

Próximo passo recomendado, somente mediante nova solicitação: implementar e validar a seleção explícita da fonte acadêmica sintética descrita na seção 9, com isolamento de dados e sinalização permanente. Esta execução encerra na preparação dos dois arquivos.
