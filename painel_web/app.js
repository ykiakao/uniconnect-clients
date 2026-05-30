const API_BASE_URL = "http://localhost:3333/api/v1";
const DEFAULT_TENANT = "universidade-norte";
const STORAGE_KEY = "uniconnect.admin.session";
const ADMIN_ROLES = new Set(["admin", "coordinator", "owner"]);

const app = document.querySelector("#app");

const state = {
  activeView: "dashboard",
  apiBaseUrl: API_BASE_URL,
  tenantSlug: DEFAULT_TENANT,
  isLoading: false,
  error: "",
  session: null,
  sidebarOpen: false,
  showPassword: false,
  chatbotOpen: false,
  chatbotNodeId: "start",
};

const navItems = [
  { id: "dashboard", label: "Dashboard", glyph: "DB" },
  { id: "users", label: "Usuários", glyph: "US" },
  { id: "courses", label: "Cursos", glyph: "CR" },
  { id: "classes", label: "Turmas", glyph: "TM" },
  { id: "reports", label: "Relatórios", glyph: "RL" },
  { id: "billing", label: "Assinatura", glyph: "AS" },
  { id: "settings", label: "Configurações", glyph: "CF" },
];

const modules = [
  {
    id: "users",
    title: "Usuários",
    text: "Perfis, vínculos institucionais e permissões.",
    readiness: 38,
  },
  {
    id: "courses",
    title: "Cursos",
    text: "Catálogo acadêmico preparado para endpoints REST.",
    readiness: 30,
  },
  {
    id: "classes",
    title: "Turmas",
    text: "Organização por curso, semestre e professor.",
    readiness: 26,
  },
  {
    id: "reports",
    title: "Relatórios",
    text: "Indicadores acadêmicos para coordenação.",
    readiness: 18,
  },
];

const moduleDetails = {
  users: {
    title: "Usuários",
    description:
      "Controle de perfis, vínculos institucionais, permissões e status de acesso.",
    icon: "US",
    status: "API pendente",
    metrics: [
      ["3", "perfis administrativos no mock atual"],
      ["5", "colunas previstas para a tabela principal"],
      ["REST", "fonte futura de dados administrativos"],
    ],
  },
  courses: {
    title: "Cursos",
    description:
      "Catálogo acadêmico com coordenador, turmas vinculadas e alunos ativos.",
    icon: "CR",
    status: "Modelo reservado",
    metrics: [
      ["Curso", "nome, área e coordenação"],
      ["Turmas", "agrupamento por período letivo"],
      ["Alunos", "uso e acompanhamento por curso"],
    ],
  },
  classes: {
    title: "Turmas",
    description:
      "Organização por curso, semestre, professor responsável e capacidade.",
    icon: "TM",
    status: "Endpoint futuro",
    metrics: [
      ["Semestre", "filtro operacional principal"],
      ["Professor", "responsável acadêmico"],
      ["Status", "ativa, encerrada ou planejada"],
    ],
  },
  reports: {
    title: "Relatórios",
    description:
      "Leitura agregada de frequência, notas, atividades pendentes e progresso.",
    icon: "RL",
    status: "Exportação futura",
    metrics: [
      ["Notas", "desempenho consolidado"],
      ["Frequencia", "risco academico"],
      ["CSV/PDF", "saida planejada"],
    ],
  },
  billing: {
    title: "Assinatura",
    description:
      "Plano atual, status, limites de uso e histórico administrativo.",
    icon: "AS",
    status: "Somente leitura",
    metrics: [
      ["Plano", "contexto do tenant"],
      ["Uso", "usuários ativos e limites"],
      ["Status", "assinatura e pendências"],
    ],
  },
  settings: {
    title: "Configurações",
    description:
      "Preferências operacionais do painel, ambiente da API e dados da instituição.",
    icon: "CF",
    status: "Base local",
    metrics: [
      ["API", "origem configurável no login"],
      ["Tenant", "slug institucional"],
      ["Sessão", "armazenamento local ou temporário"],
    ],
  },
};

const mockRows = [
  {
    name: "Patricia Almeida",
    email: "coordenador@uni.com",
    role: "Coordenadora",
    status: "Ativo",
    area: "Coordenação acadêmica",
  },
  {
    name: "Rafael Andrade",
    email: "dono@uni.com",
    role: "Mantenedor",
    status: "Ativo",
    area: "Gestão institucional",
  },
  {
    name: "Equipe administrativa",
    email: "admin@uni.com",
    role: "Admin",
    status: "Pendente",
    area: "Gestão institucional",
  },
];

const chatbotFlow = {
  start: {
    eyebrow: "Assistente UniConnect",
    title: "Como posso ajudar?",
    message:
      "Escolha um assunto abaixo. Eu vou guiando por cliques ate chegar na resposta.",
    options: [
      { label: "Registrar algo", target: "register" },
      { label: "Acessar o painel", target: "access" },
      { label: "Entender os módulos", target: "modules" },
      { label: "Resolver erro de acesso", target: "accessTrouble" },
    ],
  },
  register: {
    eyebrow: "Fluxo de registro",
    title: "O que você quer registrar?",
    message:
      "Selecione o tipo de registro para ver o caminho completo de cliques.",
    options: [
      { label: "Usuário administrativo", target: "registerUser" },
      { label: "Curso", target: "registerCourse" },
      { label: "Turma", target: "registerClass" },
      { label: "Atividade acadêmica", target: "registerActivity" },
      { label: "Nota de aluno", target: "registerGrade" },
    ],
  },
  registerUser: {
    eyebrow: "Usuários",
    title: "Como registrar um usuário administrativo",
    message:
      "Este fluxo já está mapeado no painel, mas a criação real depende do endpoint administrativo.",
    steps: [
      "Entrar no painel com perfil admin, coordenador ou mantenedor.",
      "Clicar em Usuários no menu lateral.",
      "Clicar em Novo registro quando o botão estiver habilitado.",
      "Preencher nome, e-mail institucional, perfil, área e status.",
      "Revisar o tenant exibido no topo para confirmar a instituição correta.",
      "Clicar em Salvar e conferir o novo usuário na tabela.",
    ],
    options: [
      { label: "Ver cursos", target: "registerCourse" },
      { label: "Ver erro de permissão", target: "accessTrouble" },
    ],
  },
  registerCourse: {
    eyebrow: "Cursos",
    title: "Como registrar um curso",
    message:
      "O módulo Cursos está reservado para o CRUD acadêmico do painel.",
    steps: [
      "Entrar no painel administrativo.",
      "Clicar em Cursos no menu lateral.",
      "Clicar em Novo registro quando a API do módulo estiver disponível.",
      "Informar nome do curso, área, coordenador e status.",
      "Salvar o curso.",
      "Abrir Turmas para vincular períodos e professores depois do cadastro.",
    ],
    options: [
      { label: "Ver turmas", target: "registerClass" },
      { label: "Entender módulos", target: "modules" },
    ],
  },
  registerClass: {
    eyebrow: "Turmas",
    title: "Como registrar uma turma",
    message:
      "Turmas organizam alunos por curso, semestre e professor responsável.",
    steps: [
      "Clicar em Turmas no menu lateral.",
      "Clicar em Novo registro quando o endpoint estiver pronto.",
      "Selecionar curso, semestre, período letivo e professor responsável.",
      "Definir capacidade, status e observações administrativas.",
      "Salvar a turma.",
      "Conferir se a turma aparece nos filtros de usuários, notas e relatórios.",
    ],
    options: [
      { label: "Ver notas", target: "registerGrade" },
      { label: "Ver relatórios", target: "reportsFlow" },
    ],
  },
  registerActivity: {
    eyebrow: "Atividades",
    title: "Como registrar uma atividade acadêmica",
    message:
      "Esse fluxo acontece no app do professor, não no painel administrativo atual.",
    steps: [
      "Entrar no app UniConnect com uma conta de professor.",
      "Abrir o dashboard Professor.",
      "Clicar em Criar atividade.",
      "Preencher disciplina, título, descrição, prazo, prioridade e critérios.",
      "Revisar os dados antes de publicar.",
      "Publicar para que alunos vejam em Atividades.",
    ],
    options: [
      { label: "Registrar nota", target: "registerGrade" },
      { label: "Voltar para registros", target: "register" },
    ],
  },
  registerGrade: {
    eyebrow: "Notas",
    title: "Como registrar nota de aluno",
    message:
      "O lançamento de notas é tratado pelo fluxo do professor e deve sincronizar com a API acadêmica.",
    steps: [
      "Entrar no app UniConnect com perfil professor.",
      "Abrir Professor > Notas.",
      "Selecionar turma, disciplina e aluno.",
      "Informar P1, P2, trabalho ou campos definidos pela instituição.",
      "Conferir a média calculada.",
      "Salvar para atualizar a visão Notas do aluno.",
    ],
    options: [
      { label: "Simulação do aluno", target: "studentGrades" },
      { label: "Voltar para registros", target: "register" },
    ],
  },
  access: {
    eyebrow: "Acesso",
    title: "Como acessar o painel",
    message:
      "Use uma credencial administrativa vinculada ao tenant da instituição.",
    steps: [
      "Abrir a URL do painel.",
      "Confirmar a instituição no campo Instituição.",
      "Abrir Configuração avançada apenas se precisar trocar a URL da API.",
      "Informar e-mail institucional e senha.",
      "Marcar Lembrar de mim somente em dispositivo confiável.",
      "Clicar em Entrar.",
    ],
    options: [
      { label: "Erro de acesso", target: "accessTrouble" },
      { label: "Perfis aceitos", target: "adminRoles" },
    ],
  },
  accessTrouble: {
    eyebrow: "Acesso bloqueado",
    title: "O que conferir quando não entra",
    message:
      "A maior parte dos bloqueios vem de API desligada, tenant errado ou perfil sem permissão administrativa.",
    steps: [
      "Verificar se a API uniconnect-api está rodando em http://localhost:3333/api/v1.",
      "Confirmar se a origem http://127.0.0.1:8080 está liberada no CORS da API.",
      "Conferir se o tenant está como universidade-norte ou o slug correto.",
      "Confirmar se o usuário tem perfil admin, coordinator ou owner.",
      "Tentar entrar novamente.",
      "Se a sessão antiga persistir, clicar em Sair e autenticar de novo.",
    ],
    options: [
      { label: "Perfis aceitos", target: "adminRoles" },
      { label: "Como acessar", target: "access" },
    ],
  },
  adminRoles: {
    eyebrow: "Permissões",
    title: "Quais perfis entram no painel",
    message:
      "O painel administrativo é exclusivo para perfis de gestão institucional.",
    steps: [
      "admin pode operar recursos administrativos.",
      "coordinator pode acessar fluxos acadêmicos de coordenação.",
      "owner representa o mantenedor da instituição.",
      "student e teacher não devem acessar o painel web administrativo.",
    ],
    options: [
      { label: "Registrar usuário", target: "registerUser" },
      { label: "Erro de acesso", target: "accessTrouble" },
    ],
  },
  modules: {
    eyebrow: "Módulos",
    title: "Para que serve cada módulo",
    message:
      "O painel já mostra os módulos principais e deixa claro quais dependem de endpoint futuro.",
    options: [
      { label: "Usuários", target: "moduleUsers" },
      { label: "Cursos", target: "registerCourse" },
      { label: "Turmas", target: "registerClass" },
      { label: "Relatórios", target: "reportsFlow" },
      { label: "Assinatura", target: "billingFlow" },
    ],
  },
  moduleUsers: {
    eyebrow: "Usuários",
    title: "O que fazer em Usuários",
    message:
      "Este módulo centraliza perfis, vínculos institucionais e permissões.",
    steps: [
      "Clicar em Usuários no menu.",
      "Usar a tabela para revisar pessoas recentes enquanto o endpoint não existe.",
      "Quando o CRUD estiver ativo, usar Novo registro para cadastrar usuários.",
      "Validar se cada pessoa pertence ao tenant correto.",
    ],
    options: [
      { label: "Registrar usuário", target: "registerUser" },
      { label: "Perfis aceitos", target: "adminRoles" },
    ],
  },
  reportsFlow: {
    eyebrow: "Relatórios",
    title: "Como consultar relatórios",
    message:
      "Relatórios serão a visão consolidada de desempenho, frequência e atividades.",
    steps: [
      "Clicar em Relatórios no menu lateral.",
      "Selecionar o período letivo quando o filtro estiver disponível.",
      "Filtrar por curso, turma ou disciplina.",
      "Conferir indicadores de notas, frequência e pendências.",
      "Exportar em CSV ou PDF quando a ação estiver habilitada.",
    ],
    options: [
      { label: "Ver turmas", target: "registerClass" },
      { label: "Ver notas", target: "registerGrade" },
    ],
  },
  billingFlow: {
    eyebrow: "Assinatura",
    title: "Como consultar assinatura",
    message:
      "A assinatura usa o contexto do tenant para mostrar plano, status e limites.",
    steps: [
      "Clicar em Assinatura no menu lateral.",
      "Conferir plano atual e status do tenant.",
      "Revisar usuários ativos e limites contratados quando a API expuser esses dados.",
      "Acionar o mantenedor se houver pagamento pendente.",
    ],
    options: [
      { label: "Erro de acesso", target: "accessTrouble" },
      { label: "Entender módulos", target: "modules" },
    ],
  },
  studentGrades: {
    eyebrow: "Aluno",
    title: "Como o aluno acompanha notas",
    message:
      "O aluno vê notas e simula médias no app mobile UniConnect.",
    steps: [
      "Entrar no app com perfil aluno.",
      "Abrir Notas no menu inferior.",
      "Consultar disciplinas, avaliações e média final.",
      "Usar o simulador para estimar a nota necessária.",
      "Se houver divergência, falar com o professor ou coordenação.",
    ],
    options: [
      { label: "Registrar nota", target: "registerGrade" },
      { label: "Voltar ao início", target: "start" },
    ],
  },
};

const chatbotParentMap = Object.entries(chatbotFlow).reduce(
  (parents, [nodeId, node]) => {
    node.options?.forEach((option) => {
      if (!parents[option.target]) parents[option.target] = nodeId;
    });
    return parents;
  },
  {},
);

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatRole(role) {
  const labels = {
    admin: "Administrador",
    coordinator: "Coordenador",
    owner: "Mantenedor",
    teacher: "Professor",
    student: "Aluno",
  };

  return labels[role] ?? "Usuário";
}

function formatPlan(plan) {
  const labels = {
    starter: "Starter",
    growth: "Growth",
    enterprise: "Enterprise",
  };

  return labels[plan] ?? "Starter";
}

function formatStatus(status) {
  const labels = {
    trialing: "Teste ativo",
    active: "Assinatura ativa",
    past_due: "Pagamento pendente",
  };

  return labels[status] ?? "Teste ativo";
}

function getStoredSession() {
  const raw =
    window.localStorage.getItem(STORAGE_KEY) ??
    window.sessionStorage.getItem(STORAGE_KEY);

  if (!raw) return null;

  try {
    return JSON.parse(raw);
  } catch {
    clearStoredSession();
    return null;
  }
}

function isAdminUser(user) {
  return ADMIN_ROLES.has(user?.role);
}

function normalizeLoginError(error) {
  if (error.message === "Failed to fetch") {
    return "Não foi possível conectar à API. Verifique se o backend está rodando e se a origem do painel está liberada.";
  }

  return error.message;
}

function saveStoredSession(session, remember) {
  clearStoredSession();
  const storage = remember ? window.localStorage : window.sessionStorage;
  storage.setItem(STORAGE_KEY, JSON.stringify(session));
}

function clearStoredSession() {
  window.localStorage.removeItem(STORAGE_KEY);
  window.sessionStorage.removeItem(STORAGE_KEY);
}

function getChatbotNode() {
  return chatbotFlow[state.chatbotNodeId] ?? chatbotFlow.start;
}

function renderCurrentScreen() {
  if (state.session) {
    renderAdmin();
    return;
  }

  renderLogin();
}

function openChatbot() {
  state.chatbotOpen = true;
  renderCurrentScreen();
  document.querySelector(".chatbot-option, .chatbot-close")?.focus();
}

function closeChatbot() {
  state.chatbotOpen = false;
  renderCurrentScreen();
  document.querySelector("#chatbot-toggle")?.focus();
}

function setChatbotNode(nodeId) {
  state.chatbotNodeId = chatbotFlow[nodeId] ? nodeId : "start";
  state.chatbotOpen = true;
  renderCurrentScreen();
  document.querySelector(".chatbot-option, .chatbot-back, .chatbot-reset")?.focus();
}

function goBackChatbot() {
  setChatbotNode(chatbotParentMap[state.chatbotNodeId] ?? "start");
}

function renderChatbot() {
  const node = getChatbotNode();
  const isStart = state.chatbotNodeId === "start";
  const steps = node.steps
    ?.map(
      (step, index) => `
        <li>
          <span>${index + 1}</span>
          <p>${escapeHtml(step)}</p>
        </li>
      `,
    )
    .join("");
  const options = node.options
    ?.map(
      (option) => `
        <button class="chatbot-option" type="button" data-chatbot-target="${escapeHtml(option.target)}">
          ${escapeHtml(option.label)}
        </button>
      `,
    )
    .join("");

  return `
    <section class="chatbot-widget" aria-label="Ajuda por fluxo UniConnect">
      <button
        class="chatbot-toggle"
        id="chatbot-toggle"
        type="button"
        aria-haspopup="dialog"
        aria-expanded="${state.chatbotOpen ? "true" : "false"}"
        aria-controls="chatbot-panel"
      >
        <span aria-hidden="true">?</span>
        <span class="sr-only">${state.chatbotOpen ? "Fechar ajuda" : "Abrir ajuda"}</span>
      </button>
      ${
        state.chatbotOpen
          ? `
            <div
              class="chatbot-panel"
              id="chatbot-panel"
              role="dialog"
              aria-modal="false"
              aria-labelledby="chatbot-title"
            >
              <header class="chatbot-header">
                <div>
                  <span>${escapeHtml(node.eyebrow)}</span>
                  <h2 id="chatbot-title">${escapeHtml(node.title)}</h2>
                </div>
                <button class="chatbot-close" type="button" aria-label="Fechar ajuda">Fechar</button>
              </header>
              <div class="chatbot-body" aria-live="polite">
                <article class="chatbot-message">
                  <div class="chatbot-avatar" aria-hidden="true">UC</div>
                  <p>${escapeHtml(node.message)}</p>
                </article>
                ${
                  steps
                    ? `
                      <div class="chatbot-steps">
                        <strong>Fluxo completo de cliques</strong>
                        <ol>${steps}</ol>
                      </div>
                    `
                    : ""
                }
                ${
                  options
                    ? `
                      <div class="chatbot-options" aria-label="Opções de ajuda">
                        ${options}
                      </div>
                    `
                    : ""
                }
              </div>
              <footer class="chatbot-footer">
                <button class="chatbot-back" type="button" ${isStart ? "disabled" : ""}>Voltar</button>
                <button class="chatbot-reset" type="button" ${isStart ? "disabled" : ""}>Início</button>
              </footer>
            </div>
          `
          : ""
      }
    </section>
  `;
}

function bindChatbotEvents() {
  document.onkeydown = (event) => {
    if (event.key === "Escape" && state.chatbotOpen) closeChatbot();
  };

  document.querySelector("#chatbot-toggle")?.addEventListener("click", () => {
    if (state.chatbotOpen) {
      closeChatbot();
      return;
    }

    openChatbot();
  });

  document.querySelector(".chatbot-close")?.addEventListener("click", closeChatbot);
  document.querySelector(".chatbot-back")?.addEventListener("click", goBackChatbot);
  document.querySelector(".chatbot-reset")?.addEventListener("click", () => {
    setChatbotNode("start");
  });
  document.querySelectorAll("[data-chatbot-target]").forEach((button) => {
    button.addEventListener("click", () => setChatbotNode(button.dataset.chatbotTarget));
  });
}

async function apiRequest(path, options = {}) {
  const response = await fetch(`${state.apiBaseUrl}${path}`, {
    method: options.method ?? "GET",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "x-tenant-slug": state.tenantSlug,
      ...(options.accessToken
        ? { Authorization: `Bearer ${options.accessToken}` }
        : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(payload.message ?? "Não foi possível comunicar com a API.");
  }

  return payload;
}

async function restoreSession() {
  const stored = getStoredSession();
  if (!stored?.accessToken) {
    renderLogin();
    return;
  }

  state.session = stored;
  state.apiBaseUrl = stored.apiBaseUrl ?? API_BASE_URL;
  state.tenantSlug = stored.tenant?.slug ?? stored.tenantSlug ?? DEFAULT_TENANT;

  try {
    const payload = await apiRequest("/auth/admin/me", {
      accessToken: stored.accessToken,
    });

    if (!isAdminUser(payload.user)) {
      throw new Error("Sessão sem permissão administrativa.");
    }

    state.session = {
      ...stored,
      user: payload.user,
      tenant: payload.tenant,
    };
    renderAdmin();
  } catch {
    state.session = null;
    clearStoredSession();
    renderLogin();
  }
}

function togglePasswordVisibility() {
  state.showPassword = !state.showPassword;
  renderLogin();
}

async function handleLogin(event) {
  event.preventDefault();

  const form = new FormData(event.currentTarget);
  const email = String(form.get("email") ?? "").trim();
  const password = String(form.get("password") ?? "");
  const remember = form.get("remember") === "on";
  state.apiBaseUrl = String(form.get("apiBaseUrl") ?? API_BASE_URL).trim();
  state.tenantSlug = String(form.get("tenantSlug") ?? DEFAULT_TENANT).trim();
  state.isLoading = true;
  state.error = "";
  renderLogin();

  try {
    const payload = await apiRequest("/auth/admin/login", {
      method: "POST",
      body: { email, password },
    });

    if (!isAdminUser(payload.user)) {
      throw new Error(
        "Acesso restrito a coordenadores e mantenedores da instituição.",
      );
    }

    const session = {
      accessToken: payload.accessToken,
      refreshToken: payload.refreshToken,
      expiresAt: payload.expiresAt,
      user: payload.user,
      tenant: payload.tenant,
      apiBaseUrl: state.apiBaseUrl,
      tenantSlug: state.tenantSlug,
    };

    state.session = session;
    saveStoredSession(session, remember);
    state.activeView = "dashboard";
    state.isLoading = false;
    state.showPassword = false;
    renderAdmin();
  } catch (error) {
    state.error = normalizeLoginError(error);
    state.isLoading = false;
    renderLogin();
  }
}

function logout() {
  clearStoredSession();
  state.session = null;
  state.error = "";
  state.activeView = "dashboard";
  renderLogin();
}

function setView(view) {
  state.activeView = view;
  state.sidebarOpen = false;
  renderAdmin();
}

function toggleSidebar() {
  state.sidebarOpen = !state.sidebarOpen;
  renderAdmin();
}

function renderLogin() {
  const form = document.querySelector("#login-form");
  const email = form?.querySelector("#email")?.value ?? "";
  const password = form?.querySelector("#password")?.value ?? "";
  const remember = form?.querySelector("input[name='remember']")?.checked ?? false;

  app.className = "app-shell";
  app.innerHTML = `
    <main class="login-view">
      <section class="login-panel">
        <div class="brand-block">
          <div class="brand-mark">UC</div>
          <h2 class="brand-title">UniConnect</h2>
        </div>
        <div class="login-card">
          <span class="eyebrow">ACESSO ADMINISTRATIVO PROTEGIDO</span>
          <h1>Portal da coordenação</h1>
          <p>Entrada exclusiva para coordenadores, mantenedores e administradores autorizados.</p>
          <form class="form-stack" id="login-form">
            <details class="advanced-fields">
              <summary>Configuração avançada</summary>
              <div class="field">
                <label for="apiBaseUrl">API</label>
                <input id="apiBaseUrl" name="apiBaseUrl" value="${escapeHtml(state.apiBaseUrl)}" />
              </div>
            </details>
            <div class="field">
              <label for="tenantSlug">Instituição</label>
              <input id="tenantSlug" name="tenantSlug" value="${escapeHtml(state.tenantSlug)}" />
            </div>
            <div class="field">
              <label for="email">E-mail institucional</label>
              <input id="email" name="email" type="email" autocomplete="email" value="${escapeHtml(email)}" ${state.isLoading ? "disabled" : ""} required />
            </div>
            <div class="field">
              <label for="password">Senha</label>
              <div class="password-group">
                <input id="password" name="password" type="${state.showPassword ? "text" : "password"}" autocomplete="current-password" value="${escapeHtml(password)}" ${state.isLoading ? "disabled" : ""} required />
                <button class="password-toggle" type="button" ${state.isLoading ? "disabled" : ""} title="${state.showPassword ? "Ocultar" : "Mostrar"} senha">
                  ${state.showPassword ? "Ocultar" : "Mostrar"}
                </button>
              </div>
            </div>
            <div class="check-actions">
              <label class="check-row">
                <input type="checkbox" name="remember" ${remember ? "checked" : ""} ${state.isLoading ? "disabled" : ""} />
                Lembrar de mim
              </label>
            </div>
            <div class="status-message">${escapeHtml(state.error)}</div>
            <button class="primary-button" type="submit" ${state.isLoading ? "disabled" : ""}>
              ${state.isLoading ? "Entrando..." : "Entrar"}
            </button>
          </form>
        </div>
        <p class="login-footnote">Use uma credencial administrativa vinculada à instituição.</p>
        <p class="login-links">Português (Brasil) - Suporte - Privacidade</p>
      </section>
    </main>
    ${renderChatbot()}
  `;

  document.querySelector("#login-form").addEventListener("submit", handleLogin);
  document.querySelector(".password-toggle").addEventListener("click", (e) => {
    e.preventDefault();
    togglePasswordVisibility();
  });
  bindChatbotEvents();
}

function renderAdmin() {
  const { user, tenant } = state.session;
  const active = navItems.find((item) => item.id === state.activeView);

  app.className = `app-shell admin-layout${state.sidebarOpen ? " sidebar-open" : ""}`;
  app.innerHTML = `
    <aside class="sidebar">
      <div class="sidebar-brand">
        <div class="brand-mark">UC</div>
        <div>
          <strong>UniConnect</strong>
          <span>${escapeHtml(tenant.name)}</span>
        </div>
      </div>
      <nav class="nav-list" aria-label="Navegação administrativa">
        ${navItems
          .map(
            (item) => `
              <button class="nav-button ${item.id === state.activeView ? "is-active" : ""}" data-view="${item.id}">
                <span class="nav-glyph">${item.glyph}</span>
                <span>${item.label}</span>
              </button>
            `,
          )
          .join("")}
      </nav>
      <div class="sidebar-footer">
        <div class="session-chip">
          <strong>${escapeHtml(user.name)}</strong>
          <span>${escapeHtml(formatRole(user.role))} - ${escapeHtml(user.email)}</span>
        </div>
        <button class="secondary-button" id="logout-button" type="button">Sair</button>
      </div>
    </aside>
    <button class="mobile-backdrop" id="sidebar-backdrop" aria-label="Fechar menu"></button>
    <main class="main">
      <header class="topbar">
        <button class="icon-button" id="menu-button" type="button" aria-label="Abrir menu">Menu</button>
        <div>
          <h1>${escapeHtml(active?.label ?? "Painel")}</h1>
          <p>${escapeHtml(tenant.slug)} - ${escapeHtml(formatStatus(tenant.status))}</p>
        </div>
        <div class="topbar-actions">
          <button class="secondary-button hide-small" id="refresh-button" type="button">Atualizar sessão</button>
        </div>
      </header>
      <section class="content">
        ${renderActiveView()}
      </section>
    </main>
    ${renderChatbot()}
  `;

  document.querySelectorAll("[data-view]").forEach((button) => {
    button.addEventListener("click", () => setView(button.dataset.view));
  });
  document.querySelector("#logout-button").addEventListener("click", logout);
  document.querySelector("#refresh-button").addEventListener("click", restoreSession);
  document.querySelector("#menu-button")?.addEventListener("click", toggleSidebar);
  document.querySelector("#sidebar-backdrop")?.addEventListener("click", toggleSidebar);
  bindChatbotEvents();
}

function renderActiveView() {
  if (state.activeView === "dashboard") return renderDashboard();

  const item = navItems.find((navItem) => navItem.id === state.activeView);
  const detail = moduleDetails[state.activeView] ?? {
    title: item?.label ?? "Módulo",
    description: "Módulo reservado para evolução do painel administrativo.",
    icon: "UC",
    status: "Planejado",
    metrics: [
      ["REST", "contrato futuro"],
      ["UI", "componentes padronizados"],
      ["Dados", "sem mock especifico"],
    ],
  };

  return `
    <section class="page-toolbar">
      <div class="page-title">
        <h2>${escapeHtml(detail.title)}</h2>
        <p>${escapeHtml(detail.description)}</p>
      </div>
      <span class="badge warning">${escapeHtml(detail.status)}</span>
    </section>

    <section class="state-panel">
      <span class="state-icon">${escapeHtml(detail.icon)}</span>
      <div>
        <h3>Módulo preparado para evolução</h3>
        <p>Esta tela já segue o mesmo shell, hierarquia, espaçamento e estados do painel. A implementação funcional deve entrar quando os endpoints administrativos forem definidos.</p>
        <div class="state-actions">
          <button class="secondary-button" type="button" data-view="dashboard">Voltar para visão geral</button>
          <button class="primary-button" type="button" disabled>Novo registro</button>
        </div>
      </div>
    </section>

    <section class="module-preview-grid">
      ${detail.metrics
        .map(
          ([value, label]) => `
            <article class="preview-cell">
              <strong>${escapeHtml(value)}</strong>
              <span>${escapeHtml(label)}</span>
            </article>
          `,
        )
        .join("")}
    </section>

    <section class="alert warning">
      <strong>Atenção:</strong>
      <span>Nenhuma regra de negócio foi simulada aqui. Os dados reais devem vir da API antes de habilitar criação, edição ou exclusão.</span>
    </section>
  `;
}

function renderDashboard() {
  const { user, tenant } = state.session;

  return `
    <section class="hero-card">
      <h2>Olá, ${escapeHtml(user.name.split(" ")[0] ?? user.name)}</h2>
      <div class="hero-metrics">
        <div class="hero-metric">
          <span>Instituição</span>
          <strong>${escapeHtml(tenant.name)}</strong>
          <small>${escapeHtml(formatPlan(tenant.plan))}</small>
        </div>
        <div class="hero-metric">
          <span>Usuários ativos</span>
          <strong>${escapeHtml(tenant.activeUsers)}</strong>
          <small>Contexto do tenant</small>
        </div>
        <div class="hero-metric">
          <span>Perfil</span>
          <strong>${escapeHtml(formatRole(user.role))}</strong>
          <small>${escapeHtml(formatStatus(tenant.status))}</small>
        </div>
      </div>
    </section>

    <section class="summary-grid">
      <article class="metric-card">
        <strong>4</strong>
        <span>Módulos</span>
        <small>Preparados para API</small>
      </article>
      <article class="metric-card">
        <strong>7</strong>
        <span>Pendencias</span>
        <small>Endpoints administrativos</small>
      </article>
      <article class="metric-card">
        <strong>v1</strong>
        <span>API</span>
        <small>REST versionada</small>
      </article>
      <article class="metric-card">
        <strong>${escapeHtml(formatPlan(tenant.plan))}</strong>
        <span>Plano</span>
        <small>${escapeHtml(formatStatus(tenant.status))}</small>
      </article>
    </section>

    <section class="workspace-grid">
      <article class="panel">
        <div class="panel-header">
          <div>
            <h2>Usuários recentes</h2>
            <span>Base demonstrativa até existir endpoint administrativo</span>
          </div>
          <span class="badge warning">API pendente</span>
        </div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Nome</th>
                <th>E-mail</th>
                <th>Perfil</th>
                <th>Área</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              ${mockRows
                .map(
                  (row) => `
                    <tr>
                      <td>${escapeHtml(row.name)}</td>
                      <td>${escapeHtml(row.email)}</td>
                      <td>${escapeHtml(row.role)}</td>
                      <td>${escapeHtml(row.area)}</td>
                      <td><span class="badge ${row.status === "Ativo" ? "success" : "neutral"}">${escapeHtml(row.status)}</span></td>
                    </tr>
                  `,
                )
                .join("")}
            </tbody>
          </table>
        </div>
      </article>

      <article class="panel">
        <div class="panel-header">
          <div>
            <h2>Próximas entregas</h2>
            <span>Backoffice UniConnect</span>
          </div>
        </div>
        <div class="timeline">
          <div class="timeline-item">
            <span class="dot">1</span>
            <div><strong>Endpoints administrativos</strong><span>Usuários, cursos, turmas e relatórios com permissões por perfil.</span></div>
          </div>
          <div class="timeline-item">
            <span class="dot">2</span>
            <div><strong>Gestão acadêmica</strong><span>CRUDs conectados ao schema Supabase já previsto na API.</span></div>
          </div>
          <div class="timeline-item">
            <span class="dot">3</span>
            <div><strong>Auditoria e métricas</strong><span>Logs, health checks e indicadores de operação institucional.</span></div>
          </div>
        </div>
      </article>
    </section>

    <section class="module-grid">
      ${modules
        .map(
          (module) => `
            <article class="module-card">
              <h3>${escapeHtml(module.title)}</h3>
              <p>${escapeHtml(module.text)}</p>
              <div class="progress-line" aria-label="Progresso de ${module.readiness}%">
                <span style="width: ${module.readiness}%"></span>
              </div>
            </article>
          `,
        )
        .join("")}
    </section>
  `;
}

restoreSession();
