import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import {
  STORAGE_KEY,
  performLogin,
  saveStoredSession,
  clearStoredSession,
  validateStoredSession,
  type AdminSession,
} from "./session"
import { ApiRequestError, apiRequest } from "@/lib/api-client"

const API_URL = "http://api.invalid/api/v1"
const user = {
  id: "user-fixture",
  name: "Administrative fixture",
  email: "admin@example.invalid",
  role: "admin",
  tenantSlug: "tenant-fixture",
}
const tenant = { id: "tenant-id", name: "Test institution", slug: "tenant-fixture", status: "active" }
const session: AdminSession = {
  accessToken: "synthetic-access-token",
  refreshToken: "synthetic-refresh-token",
  expiresAt: "2030-01-01T00:00:00.000Z",
  user,
  tenant,
  apiBaseUrl: API_URL,
  tenantSlug: "tenant-fixture",
}
const credentials = {
  apiBaseUrl: API_URL,
  tenantSlug: "tenant-fixture",
  email: "admin@example.invalid",
  password: "synthetic-password",
  remember: false,
}

function respond(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status })
}

function mockFetch(implementation: () => Response | Promise<Response>) {
  const spy = vi.fn(async () => implementation())
  vi.stubGlobal("fetch", spy)
  return spy
}

const failure = (status: number, code: string, message = "x") => respond(status, { error: { code, message } })
const stored = () => localStorage.getItem(STORAGE_KEY) ?? sessionStorage.getItem(STORAGE_KEY)

beforeEach(() => {
  localStorage.clear()
  sessionStorage.clear()
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("login", () => {
  it.each(["admin", "gestor", "coordinator", "owner"])("accepts the %s role", async (role) => {
    mockFetch(() => respond(200, { accessToken: "t", user: { ...user, role }, tenant }))
    const result = await performLogin(credentials)
    expect(result.user.role).toBe(role)
  })

  it.each([
    [false, "sessionStorage"],
    [true, "localStorage"],
  ])("remember=%s stores in %s only", async (remember, area) => {
    mockFetch(() => respond(200, { accessToken: "t", user, tenant }))
    await performLogin({ ...credentials, remember })
    const [used, other] = area === "localStorage" ? [localStorage, sessionStorage] : [sessionStorage, localStorage]
    expect(used.getItem(STORAGE_KEY)).toBeTruthy()
    expect(other.getItem(STORAGE_KEY)).toBeNull()
  })

  it.each([
    ["teacher role", { user: { ...user, role: "teacher" }, tenant }],
    ["missing e-mail", { user: { ...user, email: "" }, tenant }],
    ["array user", { user: [], tenant }],
    ["tenant without id", { user, tenant: { ...tenant, id: "" } }],
    ["another tenant", { user: { ...user, tenantSlug: "other" }, tenant: { ...tenant, slug: "other" } }],
  ])("rejects %s", async (_label, payload) => {
    mockFetch(() => respond(200, { accessToken: "t", ...payload }))
    await expect(performLogin(credentials)).rejects.toMatchObject({ status: 403 })
    expect(stored()).toBeNull()
  })

  it.each([undefined, null, "", "   ", 123])("rejects access token %j", async (accessToken) => {
    mockFetch(() => respond(200, { accessToken, user, tenant }))
    await expect(performLogin(credentials)).rejects.toBeInstanceOf(ApiRequestError)
  })
})

describe("session restore", () => {
  it("finishes anonymous without a request when nothing is stored", async () => {
    const spy = mockFetch(() => respond(200, {}))
    await expect(validateStoredSession(null)).resolves.toMatchObject({ kind: "anonymous" })
    expect(spy).not.toHaveBeenCalled()
  })

  it("clears corrupt JSON without a request", async () => {
    localStorage.setItem(STORAGE_KEY, "{not json")
    const spy = mockFetch(() => respond(200, {}))
    await expect(validateStoredSession(null)).resolves.toMatchObject({ kind: "anonymous" })
    expect(spy).not.toHaveBeenCalled()
    expect(stored()).toBeNull()
  })

  it.each([undefined, null, "", "   ", 123])("clears access token %j without a request", async (accessToken) => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...session, accessToken }))
    const spy = mockFetch(() => respond(200, {}))
    await validateStoredSession(null)
    expect(spy).not.toHaveBeenCalled()
    expect(stored()).toBeNull()
  })

  it("prefers local storage over session storage", async () => {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ ...session, accessToken: "temporary" }))
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...session, accessToken: "persistent" }))
    mockFetch(() => respond(200, { ...user, tenant }))
    await expect(validateStoredSession(null)).resolves.toMatchObject({
      kind: "verified",
      session: { accessToken: "persistent" },
    })
  })

  it("rejects the nested login envelope as an invalid me contract", async () => {
    saveStoredSession(session, true)
    mockFetch(() => respond(200, { user, tenant }))
    await expect(validateStoredSession(null)).resolves.toMatchObject({ kind: "denied" })
    expect(stored()).toBeNull()
  })

  it.each([
    [401, "INVALID_SESSION"],
    [403, "ADMIN_ACCESS_REQUIRED"],
    [403, "USER_INACTIVE"],
    [403, "USER_NOT_LINKED_TO_TENANT"],
  ])("clears storage on confirmed %i %s", async (status, code) => {
    saveStoredSession(session, true)
    mockFetch(() => failure(status, code))
    await expect(validateStoredSession(session)).resolves.toMatchObject({ kind: "denied" })
    expect(stored()).toBeNull()
  })

  it.each([
    ["server error", () => failure(503, "DEPENDENCY_UNAVAILABLE")],
    ["rate limit", () => failure(429, "RATE_LIMITED")],
    ["timeout", () => failure(408, "TIMEOUT")],
    ["invalid JSON on success", () => new Response("not json", { status: 200 })],
    ["network failure", (): Response => { throw new TypeError("offline") }],
  ])("keeps credentials on %s", async (_label, failing) => {
    saveStoredSession(session, true)
    mockFetch(failing)
    await expect(validateStoredSession(null)).resolves.toMatchObject({ kind: "denied" })
    expect(stored()).toBeTruthy()
    await expect(validateStoredSession(session)).resolves.toMatchObject({ kind: "kept" })
  })

  it("blocks access on tenant suspension but retains credentials", async () => {
    saveStoredSession(session, true)
    mockFetch(() => failure(403, "TENANT_SUSPENDED", "A instituicao esta suspensa."))
    await expect(validateStoredSession(session)).resolves.toMatchObject({
      kind: "denied",
      error: "A instituicao esta suspensa.",
    })
    expect(stored()).toBeTruthy()
  })

  it("logout clears both stores", () => {
    localStorage.setItem(STORAGE_KEY, "a")
    sessionStorage.setItem(STORAGE_KEY, "b")
    clearStoredSession()
    expect(stored()).toBeNull()
  })
})

describe("apiRequest", () => {
  it("shows only reviewed public messages", async () => {
    mockFetch(() => failure(401, "INVALID_CREDENTIALS", "E-mail ou senha incorretos"))
    await expect(apiRequest("/x", { baseUrl: API_URL, tenantSlug: "t" })).rejects.toMatchObject({
      status: 401,
      code: "INVALID_CREDENTIALS",
      message: "E-mail ou senha incorretos",
    })
    mockFetch(() => failure(401, "INVALID_CREDENTIALS", "internal detail"))
    await expect(apiRequest("/x", { baseUrl: API_URL, tenantSlug: "t" })).rejects.toMatchObject({
      message: "Não foi possível autenticar. Confira as credenciais ou entre novamente.",
    })
  })

  it("keeps status on non-JSON errors and drops malformed codes", async () => {
    mockFetch(() => new Response("oops", { status: 500 }))
    await expect(apiRequest("/x", { baseUrl: API_URL, tenantSlug: "t" })).rejects.toMatchObject({ status: 500, code: null })
    mockFetch(() => failure(400, "not a code"))
    await expect(apiRequest("/x", { baseUrl: API_URL, tenantSlug: "t" })).rejects.toMatchObject({ status: 400, code: null })
  })
})
