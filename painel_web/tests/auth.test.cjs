const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const STORAGE_KEY = "uniconnect.admin.session";
const API_URL = "http://api.invalid/api/v1";
const source = fs.readFileSync(path.join(__dirname, "../app.js"), "utf8");

function user(role = "admin") {
  return {
    id: "user-fixture",
    name: "Administrative fixture",
    email: "admin@example.invalid",
    role,
    tenantSlug: "tenant-fixture",
  };
}

function tenant() {
  return { id: "tenant-fixture-id", name: "Test institution", slug: "tenant-fixture", status: "active" };
}

function session(role = "admin") {
  return {
    accessToken: "synthetic-access-token",
    refreshToken: "synthetic-refresh-token",
    expiresAt: "2030-01-01T00:00:00.000Z",
    user: user(role),
    tenant: tenant(),
    apiBaseUrl: API_URL,
    tenantSlug: "tenant-fixture",
  };
}

function loginResponse(role = "admin") {
  const { accessToken, refreshToken, expiresAt } = session(role);
  return { accessToken, refreshToken, expiresAt, user: user(role), tenant: tenant() };
}

function storage(initial) {
  const values = new Map(initial === undefined ? [] : [[STORAGE_KEY, initial]]);
  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: (key) => values.delete(key),
  };
}

async function panel({ local, temporary, ...initialResponse } = {}) {
  let response = initialResponse;
  const app = { innerHTML: "", className: "" };
  const element = { addEventListener() {}, querySelector() { return null; } };
  const localStorage = storage(local);
  const sessionStorage = storage(temporary);
  const requests = [];
  const context = vm.createContext({
    document: {
      querySelector: (selector) => selector === "#app" ? app : element,
      querySelectorAll: () => [],
    },
    window: { localStorage, sessionStorage },
    FormData: class {
      constructor(fields) { this.fields = fields; }
      get(key) { return this.fields[key] ?? null; }
    },
    fetch: async (url, options) => {
      requests.push({ url, options });
      const { status = 200, payload, invalidJson, networkError, wait } = response;
      if (wait) await wait;
      if (networkError) throw new Error("Failed to fetch PRIVATE_TRANSPORT_FIXTURE");
      return {
        status,
        ok: status >= 200 && status < 300,
        json: async () => {
          if (invalidJson) throw new SyntaxError("Invalid JSON fixture");
          return payload;
        },
      };
    },
  });
  assert.match(source, /restoreSession\(\);\s*$/);
  vm.runInContext(source.replace(/restoreSession\(\);\s*$/, "globalThis.initialRestoration = restoreSession();"), context);
  await context.initialRestoration;
  return {
    app, context, requests, localStorage, sessionStorage,
    respondWith(next) { response = next; },
    get state() { return vm.runInContext("state", context); },
    async login(remember = false) {
      await context.handleLogin({
        preventDefault() {},
        currentTarget: {
          email: "  admin@example.invalid  ", password: "synthetic-password",
          remember: remember ? "on" : null,
          apiBaseUrl: API_URL, tenantSlug: "tenant-fixture",
        },
      });
    },
  };
}

function assertSignedOut(view) {
  assert.equal(view.state.session, null);
  assert.equal(view.localStorage.getItem(STORAGE_KEY), null);
  assert.equal(view.sessionStorage.getItem(STORAGE_KEY), null);
  assert.match(view.app.innerHTML, /id="login-form"/);
  assert.doesNotMatch(view.app.innerHTML, /id="logout-button"/);
}

for (const [role, label] of [
  ["admin", "Administrador"], ["gestor", "Coordenador"],
  ["coordinator", "Coordenador"], ["owner", "Mantenedor"],
]) {
  test(`login accepts ${role} and preserves the login contract`, async () => {
    const view = await panel({ payload: loginResponse(role) });
    await view.login();
    assert.equal(view.state.session.user.role, role);
    assert.equal(view.state.session.tenant.slug, "tenant-fixture");
    assert.match(view.app.innerHTML, new RegExp(`${label} - admin@example.invalid`));
    assert.equal(view.state.isLoading, false);
    assert.equal(view.state.error, "");
    assert.equal(view.requests.length, 1);
    const request = view.requests[0];
    assert.equal(request.url, `${API_URL}/auth/admin/login`);
    assert.equal(request.options.method, "POST");
    assert.equal(request.options.headers["x-tenant-slug"], "tenant-fixture");
    assert.equal(request.options.headers.Authorization, undefined);
    assert.deepEqual(JSON.parse(request.options.body), {
      email: "admin@example.invalid", password: "synthetic-password",
    });
    const saved = JSON.parse(view.sessionStorage.getItem(STORAGE_KEY));
    assert.deepEqual(saved, session(role));
    assert.equal(view.localStorage.getItem(STORAGE_KEY), null);
  });
}

for (const remember of [false, true]) {
  test(`login preserves ${remember ? "persistent" : "temporary"} storage and logout clears both stores`, async () => {
    const view = await panel({ payload: loginResponse("gestor") });
    view.localStorage.setItem(STORAGE_KEY, "stale-fixture");
    view.sessionStorage.setItem(STORAGE_KEY, "stale-fixture");
    await view.login(remember);
    const selected = remember ? view.localStorage : view.sessionStorage;
    const other = remember ? view.sessionStorage : view.localStorage;
    assert.deepEqual(JSON.parse(selected.getItem(STORAGE_KEY)), session("gestor"));
    assert.equal(other.getItem(STORAGE_KEY), null);
    view.context.logout();
    assertSignedOut(view);
    assert.equal(view.requests.length, 1);
  });
}

for (const role of ["admin", "gestor", "coordinator", "owner"]) {
  for (const location of ["local", "temporary"]) {
    test(`restore accepts flat ${role} user from ${location} storage`, async () => {
      const stored = JSON.stringify(session(role));
      const currentUser = { ...user(role), name: "Current fixture name" };
      const currentTenant = { ...tenant(), name: "Current institution name" };
      const view = await panel({ [location]: stored, payload: { ...currentUser, tenant: currentTenant } });
      assert.deepEqual(JSON.parse(JSON.stringify(view.state.session.user)), currentUser);
      assert.deepEqual(JSON.parse(JSON.stringify(view.state.session.tenant)), currentTenant);
      assert.equal(view.state.session.accessToken, session().accessToken);
      assert.equal(view.state.session.refreshToken, session().refreshToken);
      assert.match(view.app.innerHTML, /Current fixture name/);
      assert.match(view.app.innerHTML, /Current institution name/);
      assert.equal((location === "local" ? view.localStorage : view.sessionStorage).getItem(STORAGE_KEY), stored);
      assert.equal((location === "local" ? view.sessionStorage : view.localStorage).getItem(STORAGE_KEY), null);
      assert.equal(view.requests.length, 1);
      assert.equal(view.requests[0].url, `${API_URL}/auth/admin/me`);
      assert.equal(view.requests[0].options.method, "GET");
      assert.equal(view.requests[0].options.headers.Authorization, `Bearer ${session().accessToken}`);
      assert.equal(view.requests[0].options.headers["x-tenant-slug"], "tenant-fixture");
      assert.equal(view.requests[0].options.body, undefined);
    });
  }
}

const invalidUsers = [
  ["missing user", undefined], ["null user", null], ["array user", []],
  ...["student", "teacher", "unknown", "", null].map((role) => [`unauthorized role ${String(role)}`, user(role)]),
  ...["id", "name", "email", "tenantSlug"].flatMap((field) => [
    [`missing ${field}`, { ...user(), [field]: undefined }],
    [`blank ${field}`, { ...user(), [field]: "   " }],
    [`non-string ${field}`, { ...user(), [field]: 1 }],
  ]),
];

for (const [description, invalidUser] of invalidUsers) {
  test(`login rejects ${description}`, async () => {
    const view = await panel({ payload: { ...loginResponse(), user: invalidUser } });
    await view.login();
    assertSignedOut(view);
    assert.notEqual(view.state.error, "");
    assert.equal(view.state.isLoading, false);
  });
  test(`restore rejects ${description} and clears both stores`, async () => {
    const flat = invalidUser === undefined || invalidUser === null || Array.isArray(invalidUser)
      ? invalidUser : { ...invalidUser, tenant: tenant() };
    const view = await panel({ local: JSON.stringify(session()), temporary: JSON.stringify(session()), payload: flat });
    assertSignedOut(view);
    assert.equal(view.requests.length, 1);
  });
}

const invalidTenants = [
  ["missing tenant", undefined], ["null tenant", null], ["array tenant", []],
  ["different tenant", { ...tenant(), slug: "other-tenant" }],
  ...["id", "name", "slug"].flatMap((field) => [
    [`missing tenant ${field}`, { ...tenant(), [field]: undefined }],
    [`blank tenant ${field}`, { ...tenant(), [field]: " " }],
  ]),
];

for (const [description, invalidTenant] of invalidTenants) {
  test(`login rejects ${description}`, async () => {
    const view = await panel({ payload: { ...loginResponse(), tenant: invalidTenant } });
    await view.login();
    assertSignedOut(view);
  });
  test(`restore rejects ${description}`, async () => {
    const view = await panel({ local: JSON.stringify(session()), payload: { ...user(), tenant: invalidTenant } });
    assertSignedOut(view);
  });
}

test("login rejects a user belonging to another tenant", async () => {
  const view = await panel({ payload: { ...loginResponse(), user: { ...user(), tenantSlug: "other-tenant" } } });
  await view.login();
  assertSignedOut(view);
});

test("restore rejects a user belonging to another tenant", async () => {
  const view = await panel({ local: JSON.stringify(session()), payload: { ...user(), tenantSlug: "other-tenant", tenant: tenant() } });
  assertSignedOut(view);
});

test("restore rejects the nested login envelope as an invalid me contract", async () => {
  const view = await panel({ local: JSON.stringify(session()), payload: loginResponse() });
  assertSignedOut(view);
});

for (const accessToken of [undefined, null, "", "   ", 123]) {
  test(`login rejects invalid access token ${JSON.stringify(accessToken)}`, async () => {
    const view = await panel({ payload: { ...loginResponse(), accessToken } });
    await view.login();
    assertSignedOut(view);
  });
  test(`restore clears invalid access token ${JSON.stringify(accessToken)} without a request`, async () => {
    const stored = JSON.stringify({ ...session(), accessToken });
    const view = await panel({ local: stored, temporary: stored, payload: { ...user(), tenant: tenant() } });
    assertSignedOut(view);
    assert.equal(view.requests.length, 0);
  });
}

test("restore clears corrupt stored JSON without a request", async () => {
  const view = await panel({ local: "{invalid", temporary: JSON.stringify(session()) });
  assertSignedOut(view);
  assert.equal(view.requests.length, 0);
});

test("restore prefers local storage over session storage", async () => {
  const preferred = session();
  const other = { ...session(), accessToken: "other-synthetic-token" };
  const view = await panel({ local: JSON.stringify(preferred), temporary: JSON.stringify(other), payload: { ...user(), tenant: tenant() } });
  assert.equal(view.state.session.accessToken, preferred.accessToken);
  assert.equal(view.requests[0].options.headers.Authorization, `Bearer ${preferred.accessToken}`);
});

for (const [status, code, message] of [
  [401, "INVALID_SESSION", "Sessao invalida ou expirada."],
  [403, "ADMIN_ACCESS_REQUIRED", "Sessao sem permissao administrativa."],
  [403, "USER_INACTIVE", "Vinculo institucional desativado."],
  [403, "USER_NOT_LINKED_TO_TENANT", "Usuário não vinculado à instituição."],
]) {
  test(`restore clears storage on confirmed ${code} without refresh`, async () => {
    const stored = JSON.stringify(session());
    const view = await panel({ local: stored, temporary: stored, status, payload: { error: { code, message } } });
    assertSignedOut(view);
    assert.equal(view.state.error, message);
    assert.equal(view.requests.length, 1);
  });
}

for (const [name, failure, message] of [
  ["network failure", { networkError: true }, /conectar à API/],
  ["non-JSON success", { invalidJson: true }, /resposta inválida/],
  ["non-JSON gateway error", { status: 502, invalidJson: true }, /temporariamente indisponível/],
  ["temporary dependency failure", { status: 503, payload: { error: {
    code: "DEPENDENCY_UNAVAILABLE",
    message: "O servico de dados esta temporariamente indisponivel. Tente novamente mais tarde.",
  } } }, /temporariamente indisponivel/],
  ["rate limit", { status: 429, payload: { error: { code: "AUTH_RATE_LIMIT" } } }, /Tente novamente/],
]) {
  test(`startup preserves saved credentials without granting access on ${name}`, async () => {
    const stored = JSON.stringify(session());
    const view = await panel({ local: stored, ...failure });
    assert.equal(view.state.session, null);
    assert.equal(view.localStorage.getItem(STORAGE_KEY), stored);
    assert.match(view.state.error, message);
    assert.match(view.app.innerHTML, /id="login-form"/);
    assert.doesNotMatch(view.app.innerHTML, /id="logout-button"/);
    assert.equal(view.requests.length, 1);
    view.respondWith({ payload: { ...user(), tenant: tenant() } });
    await view.context.restoreSession();
    assert.equal(view.state.session.user.id, user().id);
    assert.equal(view.state.error, "");
  });

  test(`manual validation preserves an already verified session on ${name}`, async () => {
    const stored = JSON.stringify(session());
    const view = await panel({ temporary: stored, payload: { ...user(), tenant: tenant() } });
    const active = view.state.session;
    view.respondWith(failure);
    await view.context.restoreSession();
    assert.equal(view.state.session, active);
    assert.equal(view.sessionStorage.getItem(STORAGE_KEY), stored);
    assert.match(view.state.error, message);
    assert.match(view.app.innerHTML, message);
    assert.match(view.app.innerHTML, /id="logout-button"/);
    assert.equal(view.requests.length, 2);
  });

  test(`login reports ${name} safely`, async () => {
    const view = await panel(failure);
    await view.login();
    assertSignedOut(view);
    assert.match(view.state.error, message);
    assert.doesNotMatch(view.app.innerHTML, /PRIVATE_TRANSPORT_FIXTURE/);
  });
}

test("login uses the public authentication message from the nested envelope", async () => {
  const message = "E-mail ou senha incorretos";
  const view = await panel({ status: 401, payload: {
    message: "PRIVATE_LEGACY_FIXTURE",
    error: { code: "INVALID_CREDENTIALS", message, requestId: "PRIVATE_REQUEST_FIXTURE" },
  } });
  await view.login();
  assertSignedOut(view);
  assert.equal(view.state.error, message);
  assert.doesNotMatch(view.app.innerHTML, /PRIVATE_/);
});

test("apiRequest retains HTTP status and error code, including non-JSON errors", async () => {
  const message = "Acesso administrativo restrito a coordenadores e mantenedores.";
  const view = await panel({ status: 403, payload: { error: { code: "ADMIN_ACCESS_REQUIRED", message } } });
  await assert.rejects(view.context.apiRequest("/auth/admin/login"),
    (error) => error.status === 403 && error.code === "ADMIN_ACCESS_REQUIRED" && error.message === message);
  view.respondWith({ status: 503, invalidJson: true });
  await assert.rejects(view.context.apiRequest("/auth/admin/me"),
    (error) => error.status === 503 && error.code === null && /temporariamente indisponível/.test(error.message));
});

for (const payload of [
  null,
  { message: "PRIVATE_LEGACY_FIXTURE" },
  { error: { code: "ADMIN_ACCESS_REQUIRED" } },
  { error: { message: "PRIVATE_UNBOUND_FIXTURE" } },
  { error: { code: "ADMIN_ACCESS_REQUIRED", message: "<b>Bearer PRIVATE_TOKEN_FIXTURE</b>", requestId: "PRIVATE_ID_FIXTURE" } },
  { error: { code: "UNRECOGNIZED_ERROR", message: "PRIVATE_INTERNAL_FIXTURE" } },
]) {
  test(`login uses a safe authorization fallback for incomplete or unsafe envelopes (${Object.keys(payload ?? {}).join(",")})`, async () => {
    const view = await panel({ status: 403, payload });
    await view.login();
    assertSignedOut(view);
    assert.match(view.state.error, /permissão/);
    assert.doesNotMatch(view.app.innerHTML, /PRIVATE_|Bearer|conectar à API/);
  });
}

test("manual validation blocks access on tenant suspension and retains credentials for later validation", async () => {
  const stored = JSON.stringify(session());
  const view = await panel({ local: stored, payload: { ...user(), tenant: tenant() } });
  view.respondWith({ status: 403, payload: { error: {
    code: "TENANT_SUSPENDED", message: "A instituicao esta suspensa.",
  } } });
  await view.context.restoreSession();
  assert.equal(view.state.session, null);
  assert.equal(view.localStorage.getItem(STORAGE_KEY), stored);
  assert.match(view.app.innerHTML, /instituicao esta suspensa/);
  assert.doesNotMatch(view.app.innerHTML, /id="logout-button"/);
});

test("overlapping manual validations share one request and honor its denial", async () => {
  const view = await panel({ local: JSON.stringify(session()), payload: { ...user(), tenant: tenant() } });
  let release;
  view.respondWith({
    status: 401,
    payload: { error: { code: "INVALID_SESSION", message: "Sessao invalida ou expirada." } },
    wait: new Promise((resolve) => { release = resolve; }),
  });
  const first = view.context.restoreSession();
  const second = view.context.restoreSession();
  release();
  await Promise.all([first, second]);
  assert.equal(view.requests.length, 2);
  assertSignedOut(view);
});

test("a pending manual validation cannot restore a session after logout", async () => {
  const view = await panel({ temporary: JSON.stringify(session()), payload: { ...user(), tenant: tenant() } });
  let release;
  view.respondWith({
    payload: { ...user(), tenant: tenant() },
    wait: new Promise((resolve) => { release = resolve; }),
  });
  const validation = view.context.restoreSession();
  view.context.logout();
  release();
  await validation;
  assertSignedOut(view);
  assert.equal(view.state.error, "");
});

test("without a stored session the panel only renders login", async () => {
  const view = await panel();
  assertSignedOut(view);
  assert.equal(view.requests.length, 0);
});
