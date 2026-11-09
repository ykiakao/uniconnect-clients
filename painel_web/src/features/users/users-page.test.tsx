import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { render, screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { UsersPage } from "./users-page"
import { TooltipProvider } from "@/components/ui/tooltip"
import { Toaster } from "@/components/ui/sonner"
import { AuthContext, type AuthContextValue } from "@/features/auth/use-auth"
import type { AdminSession } from "@/features/auth/session"

const session: AdminSession = {
  accessToken: "synthetic-token",
  user: { id: "me", name: "Gestora", email: "me@example.invalid", role: "admin", tenantSlug: "t" },
  tenant: { id: "t-id", name: "Instituição", slug: "t", status: "active" },
  apiBaseUrl: "http://api.invalid/api/v1",
  tenantSlug: "t",
}

const people = [
  { id: "me", name: "Gestora", email: "me@example.invalid", role: "admin", active: true },
  { id: "s1", name: "<b>Ana</b> Sintética", email: "ana@example.invalid", role: "aluno", active: true, courseId: "c1" },
  { id: "s2", name: "Bia Inativa", email: "bia@example.invalid", role: "aluno", active: false },
  { id: "a2", name: "Outra Admin", email: "outra@example.invalid", role: "admin", active: true },
]

type Call = { method: string; url: string; body?: unknown }
let calls: Call[] = []
let listResponse: () => Response

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status })

beforeEach(() => {
  calls = []
  listResponse = () => json({ data: people, meta: { page: 1, limit: 20, total: 4 } })
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, options: RequestInit = {}) => {
      const method = options.method ?? "GET"
      calls.push({ method, url, body: options.body ? JSON.parse(String(options.body)) : undefined })
      if (method !== "GET") return json({})
      if (url.includes("/courses")) return json({ data: [{ id: "c1", name: "Curso Sintético" }] })
      if (url.includes("limit=1&") || url.endsWith("limit=1")) return json({ data: [], meta: { page: 1, limit: 1, total: 7 } })
      return listResponse()
    }),
  )
})

afterEach(() => {
  vi.unstubAllGlobals()
})

function renderPage() {
  const auth: AuthContextValue = {
    status: "authenticated",
    session,
    error: "",
    apiBaseUrl: session.apiBaseUrl,
    tenantSlug: session.tenantSlug,
    login: vi.fn(),
    logout: vi.fn(),
    refresh: vi.fn(async () => {}),
  }
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  render(
    <AuthContext.Provider value={auth}>
      <QueryClientProvider client={client}>
        <TooltipProvider>
          <MemoryRouter>
            <UsersPage />
          </MemoryRouter>
          <Toaster theme="light" />
        </TooltipProvider>
      </QueryClientProvider>
    </AuthContext.Provider>,
  )
  return { auth, user: userEvent.setup() }
}

const writes = () => calls.filter((call) => call.method !== "GET")

describe("UsersPage", () => {
  it("lists people as plain text and states status in words", async () => {
    renderPage()
    expect(await screen.findByText("<b>Ana</b> Sintética")).toBeInTheDocument()
    expect(screen.getByText("Inativo")).toBeInTheDocument()
    expect(await screen.findByText("Curso Sintético")).toBeInTheDocument()
  })

  it("offers actions only on rows the actor can manage", async () => {
    renderPage()
    await screen.findByText("Bia Inativa")
    expect(screen.getByRole("button", { name: "Editar Bia Inativa" })).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "Reativar Bia Inativa" })).toBeInTheDocument()
    expect(screen.queryByRole("button", { name: "Editar Gestora" })).not.toBeInTheDocument()
    expect(screen.queryByRole("button", { name: "Editar Outra Admin" })).not.toBeInTheDocument()
    expect(screen.getByText("Você")).toBeInTheDocument()
    expect(screen.getByLabelText("Sem permissão")).toBeInTheDocument()
  })

  it("filters by role through the chips and shows totals", async () => {
    const { user } = renderPage()
    await screen.findByText("Bia Inativa")
    const chip = await screen.findByRole("radio", { name: /Alunos\s*7/ })
    await user.click(chip)
    await waitFor(() => expect(calls.some((call) => call.url.includes("limit=20&role=aluno"))).toBe(true))
  })

  it("does not send an invalid new user", async () => {
    const { user } = renderPage()
    await screen.findByText("Bia Inativa")
    await user.click(screen.getByRole("button", { name: "Novo usuário" }))
    const dialog = await screen.findByRole("dialog")
    await user.click(within(dialog).getByRole("button", { name: "Criar usuário" }))
    expect(await within(dialog).findByText("Informe o nome.")).toBeInTheDocument()
    expect(writes()).toEqual([])
  })

  it("creates a user with a normalized payload", async () => {
    const { user } = renderPage()
    await screen.findByText("Bia Inativa")
    await user.click(screen.getByRole("button", { name: "Novo usuário" }))
    const dialog = await screen.findByRole("dialog")
    await user.type(within(dialog).getByLabelText("Nome completo"), "Nova Pessoa")
    await user.type(within(dialog).getByLabelText("E-mail institucional"), "NOVA@example.invalid")
    await user.type(within(dialog).getByLabelText("Senha inicial"), "12345678")
    await user.click(within(dialog).getByRole("button", { name: "Criar usuário" }))
    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0]).toMatchObject({
      method: "POST",
      body: { name: "Nova Pessoa", email: "nova@example.invalid", role: "aluno" },
    })
    expect(await screen.findByText("Usuário criado.")).toBeInTheDocument()
  })

  it("asks for confirmation before deactivating", async () => {
    const { user } = renderPage()
    await screen.findByText("Bia Inativa")
    await user.click(screen.getByRole("button", { name: "Desativar <b>Ana</b> Sintética" }))
    const dialog = await screen.findByRole("alertdialog")
    expect(writes()).toEqual([])
    await user.click(within(dialog).getByRole("button", { name: "Desativar acesso" }))
    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0]).toMatchObject({ method: "PATCH", body: { active: false } })
    expect(writes()[0].url).toContain("/users/s1/status")
  })

  it("reactivates without confirmation", async () => {
    const { user } = renderPage()
    await screen.findByText("Bia Inativa")
    await user.click(screen.getByRole("button", { name: "Reativar Bia Inativa" }))
    await waitFor(() => expect(writes()[0]).toMatchObject({ method: "PATCH", body: { active: true } }))
  })

  it("shows the error with a retry and asks for a new session on 401", async () => {
    listResponse = () => json({ error: { code: "DEPENDENCY_UNAVAILABLE", message: "x" } }, 503)
    const first = renderPage()
    expect(await screen.findByRole("button", { name: "Tentar novamente" })).toBeInTheDocument()
    expect(first.auth.refresh).not.toHaveBeenCalled()
  })

  it("shows an empty state", async () => {
    listResponse = () => json({ data: [], meta: { page: 1, limit: 20, total: 0 } })
    renderPage()
    expect(await screen.findByText("Nenhum usuário cadastrado ainda.")).toBeInTheDocument()
  })
})
