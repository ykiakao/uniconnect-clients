# Direcao Visual do Painel Web

## Tese

O painel web do UniConnect deve parecer uma extensao direta do app Flutter: claro, confiavel, organizado e feito para uso repetido por coordenadores e gestores. A interface precisa priorizar leitura rapida, comparacao de dados e acao objetiva, sem atmosfera de landing page.

## Personalidade

* Institucional sem ficar burocratico
* Tecnico sem parecer cru
* Academico sem usar estetica escolar infantil
* SaaS operacional, nao marketing
* Calmo, preciso e responsivo

## Direcao Visual

Usar os mesmos tokens visuais do Flutter:

* Fonte: Inter
* Primaria: `#004A99`
* Primaria escura: `#003B7A`
* Primaria suave: `#E7F1FF`
* Secundaria: `#F58220`
* Secundaria suave: `#FFF2E8`
* Fundo: `#F4F7FB`
* Texto principal: `#212529`
* Texto secundario: `#6C757D`
* Borda: `#DEE2E6`
* Sucesso: `#2E7D32`
* Perigo: `#E53935`

A composicao deve repetir o vocabulario do app mobile: cards brancos com borda clara e raio 16, botoes primarios azuis com raio 12, inputs preenchidos com raio 12 e hero cards azuis para resumos de alto nivel.

A composicao deve favorecer:

* Tabelas legiveis
* Metricas compactas
* Filtros visiveis
* Estados vazios uteis
* Alertas discretos
* Formularios de cadastro sem excesso visual

## Layout

O desktop deve manter uma navegacao lateral fixa com area principal ampla. O mobile deve recolher a navegacao em menu lateral, preservando leitura e acoes principais.

As telas futuras devem seguir esta hierarquia:

1. Topbar com contexto da tela e instituicao
2. Acoes primarias alinhadas a direita
3. Filtros ou busca quando houver listas
4. Conteudo principal em tabela ou grade funcional
5. Estados auxiliares abaixo ou em paineis laterais

## Componentes

Preferir componentes densos e previsiveis:

* Botoes primarios para criacao e confirmacao
* Botoes secundarios para atualizar, exportar e cancelar
* Badges para status academico, assinatura e perfil
* Tabelas para usuarios, cursos, turmas e relatorios
* Paineis apenas para grupos funcionais
* Modais ou paineis laterais para criacao e edicao

Cards devem ser usados com parcimonia: metricas, resumos e itens repetidos. Nao usar cards aninhados.

## Tipografia

Usar tipografia de sistema ou Inter quando houver pipeline futuro. Titulos devem ser contidos. Nada de hero text dentro do painel depois do login. Numeros e indicadores podem ter mais peso, mas sempre com rotulo proximo.

## Cores

Base atual recomendada:

* Fundo: cinza frio claro
* Superficie: branco
* Texto principal: azul-carvao
* Texto secundario: cinza medio
* Acao principal: azul UniConnect
* Acao secundaria e alertas leves: laranja UniConnect
* Estados: verde, laranja e vermelho apenas para significado
* Sidebar: clara, com selecao em `primarySoft`

Evitar paletas alternativas. O painel nao deve introduzir verde como marca principal nem sidebar escura se isso afastar a experiencia do Flutter.

## Movimento

Animacoes devem ser discretas e funcionais:

* Menu lateral no mobile
* Hover em botoes e linhas de tabela
* Loading states em botoes e listas
* Transicoes curtas para modais

Nao usar animacao ornamental.

## Antipadroes

Nao fazer:

* Hero de marketing no painel autenticado
* Cards decorativos demais
* Gradientes como tema principal
* Ilustracoes abstratas em telas operacionais
* Textos explicando a interface dentro da propria UI
* Layout espacoso demais para listas administrativas
* Acoes criticas sem confirmacao

## Proximas Telas

Usuarios:

* Tabela principal com nome, e-mail, perfil, curso, status e ultima atividade
* Filtros por perfil e status
* Acao primaria: novo usuario
* Edicao em painel lateral

Cursos:

* Lista compacta com curso, coordenador, turmas e alunos ativos
* Acao primaria: novo curso

Turmas:

* Tabela com turma, curso, semestre, professor e alunos
* Filtros por curso e semestre

Relatorios:

* Indicadores agregados
* Exportacao futura
* Foco em frequencia, notas e atividades pendentes

Assinatura:

* Plano atual, status, uso e historico
* Acoes claras para atualizar dados e revisar limites
