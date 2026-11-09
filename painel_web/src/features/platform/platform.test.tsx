import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { render, screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter, Route, Routes } from "react-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { PlatformApp } from "./platform-app"
import { PLATFORM_STORAGE_KEY } from "./platform-session"
import { Toaster } from "@/components/ui/sonner"
import { TooltipProvider } from "@/components/ui/tooltip"

const INSTITUTION = {
  id: "11111111-1111-4111-8111-111111111111",
  name: "EduKMais",
  slug: "edukmais",
  operationalStatus: "active",
  version: 3,
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
}
type Call = { method: string; url: string; headers: Record<string, string>; body?: unknown }
let calls: Call[] = []
let meStatus = 200
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status })
const writes = () => calls.filter((call) => call.method !== "GET")
const page = (data: unknown[]) => ({ data, meta: { page: 1, limit: 20, total: data.length } })

beforeEach(() => {
  calls = []
  meStatus = 200
  sessionStorage.clear()
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, options: RequestInit = {}) => {
      const method = options.method ?? "GET"
      calls.push({ method, url, headers: options.headers as Record<string, string>, body: options.body ? JSON.parse(String(options.body)) : undefined })
      if (url.endsWith("/auth/platform/login")) return json({ accessToken: "platform-token", authorization: {} })
      if (url.endsWith("/auth/platform/me")) return meStatus === 200 ? json({ authorization: {} }) : json({ error: { code: "INVALID_SESSION", message: "x" } }, meStatus)
      if (method !== "GET") return json(INSTITUTION)
      if (url.includes("/audit") || url.includes("/admin-provisioning") || url.includes("/responsible/history")) return json(page([]))
      if (url.endsWith("/responsible")) return json({ error: { code: "NOT_FOUND", message: "x" } }, 404)
      if (url.includes(`/institutions/${INSTITUTION.id}`)) return json(INSTITUTION)
      return json(page([INSTITUTION]))
    }),
  )
})

afterEach(() => vi.unstubAllGlobals())

function renderApp(entry = "/plataforma") {
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <TooltipProvider>
        <MemoryRouter initialEntries={[entry]}>
          <Routes>
            <Route path="/plataforma/*" element={<PlatformApp />} />
          </Routes>
        </MemoryRouter>
        <Toaster theme="light" />
      </TooltipProvider>
    </QueryClientProvider>,
  )
  return userEvent.setup()
}

function signedIn() {
  sessionStorage.setItem(PLATFORM_STORAGE_KEY, JSON.stringify({ accessToken: "platform-token", apiBaseUrl: "http://api.invalid/api/v1" }))
}

describe("platform administration", () => {
  it("links to the institution login", async () => {
    renderApp()

    expect((await screen.findByRole("link", { name: "Portal da coordenação" })).getAttribute("href")).toBe("/")
  })

  it("signs in without a tenant and keeps the token out of localStorage", async () => {
    const user = renderApp()
    await user.type(await screen.findByLabelText("E-mail"), "root@example.invalid")
    await user.type(screen.getByLabelText("Senha"), "synthetic-password")
    await user.click(screen.getByRole("button", { name: "Entrar" }))
    expect(await screen.findByText("EduKMais")).toBeInTheDocument()
    const login = calls.find((call) => call.url.endsWith("/auth/platform/login"))
    expect(login?.headers["x-tenant-slug"]).toBeUndefined()
    expect(sessionStorage.getItem(PLATFORM_STORAGE_KEY)).toBeTruthy()
    expect(localStorage.getItem(PLATFORM_STORAGE_KEY)).toBeNull()
  })

  it("drops a rejected session and shows the login", async () => {
    signedIn()
    meStatus = 401
    renderApp()
    expect(await screen.findByLabelText("E-mail")).toBeInTheDocument()
    expect(sessionStorage.getItem(PLATFORM_STORAGE_KEY)).toBeNull()
  })

  it("creates an institution with an idempotency key and validates the slug", async () => {
    signedIn()
    const user = renderApp()
    await screen.findByText("EduKMais")
    await user.click(screen.getByRole("button", { name: "Nova instituição" }))
    const dialog = await screen.findByRole("dialog")
    await user.type(within(dialog).getByLabelText("Nome"), "Nova")
    await user.type(within(dialog).getByLabelText("Identificador"), "Com Espaco")
    await user.click(within(dialog).getByRole("button", { name: "Salvar" }))
    expect(await within(dialog).findByText(/letras minúsculas/)).toBeInTheDocument()
    expect(writes()).toEqual([])
    await user.clear(within(dialog).getByLabelText("Identificador"))
    await user.type(within(dialog).getByLabelText("Identificador"), "nova-escola")
    await user.click(within(dialog).getByRole("button", { name: "Salvar" }))
    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0].body).toEqual({ name: "Nova", slug: "nova-escola" })
    expect(writes()[0].headers["Idempotency-Key"]).toMatch(/^[0-9a-f-]{36}$/)
  })

  it("asks before suspending and sends the expected version", async () => {
    signedIn()
    const user = renderApp(`/plataforma/instituicoes/${INSTITUTION.id}`)
    await user.click(await screen.findByRole("button", { name: "Suspender" }))
    const dialog = await screen.findByRole("alertdialog")
    expect(writes()).toEqual([])
    await user.click(within(dialog).getByRole("button", { name: "Suspender instituição" }))
    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0].url).toContain("/suspend")
    expect(writes()[0].body).toEqual({ expectedVersion: 3 })
    expect(writes()[0].headers["Idempotency-Key"]).toBeTruthy()
  })

  it("treats a missing responsible as an empty state", async () => {
    signedIn()
    renderApp(`/plataforma/instituicoes/${INSTITUTION.id}`)
    expect(await screen.findByText("Nenhum responsável definido.")).toBeInTheDocument()
  })
})
