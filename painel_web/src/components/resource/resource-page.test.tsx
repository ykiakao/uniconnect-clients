import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { render, screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { ResourcePage, type ResourceConfig } from "./resource-page"
import { Toaster } from "@/components/ui/sonner"
import { TooltipProvider } from "@/components/ui/tooltip"
import { AuthContext, type AuthContextValue } from "@/features/auth/use-auth"
import type { AdminSession } from "@/features/auth/session"

const session: AdminSession = {
  accessToken: "synthetic-token",
  user: { id: "me", name: "Gestora", email: "me@example.invalid", role: "admin", tenantSlug: "t" },
  tenant: { id: "t-id", name: "Instituição", slug: "t", status: "active" },
  apiBaseUrl: "http://api.invalid/api/v1",
  tenantSlug: "t",
}

type Course = { id: string; name: string; description?: string }
const config: ResourceConfig<Course> = {
  label: "Cursos",
  newLabel: "Novo curso",
  editTitle: "Editar curso",
  basePath: "/courses",
  updateMethod: "PUT",
  updateMode: "full",
  canDelete: true,
  emptyMessage: "Nenhum curso cadastrado ainda.",
  rowName: (row) => row.name,
  columns: [{ key: "name", header: "Nome", isPrimary: true, cell: (row) => row.name }],
  fields: [
    { name: "name", label: "Nome", required: true },
    { name: "description", label: "Descrição", type: "textarea" },
  ],
}

type Call = { method: string; url: string; body?: unknown }
let calls: Call[] = []
let rows: Course[] = []
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status })
const writes = () => calls.filter((call) => call.method !== "GET")

beforeEach(() => {
  calls = []
  rows = [{ id: "c1", name: "Ciência", description: "Texto" }]
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, options: RequestInit = {}) => {
      const method = options.method ?? "GET"
      calls.push({ method, url, body: options.body ? JSON.parse(String(options.body)) : undefined })
      if (method === "DELETE") return new Response(null, { status: 204 })
      if (method !== "GET") return json({})
      return json({ data: rows, meta: { page: 1, limit: 20, total: rows.length } })
    }),
  )
})

afterEach(() => vi.unstubAllGlobals())

function renderPage() {
  const auth: AuthContextValue = {
    status: "authenticated",
    session,
    error: "",
    apiBaseUrl: session.apiBaseUrl,
    tenantSlug: "t",
    login: vi.fn(),
    logout: vi.fn(),
    refresh: vi.fn(async () => {}),
  }
  render(
    <AuthContext.Provider value={auth}>
      <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
        <TooltipProvider>
          <MemoryRouter>
            <ResourcePage config={config} />
          </MemoryRouter>
          <Toaster theme="light" />
        </TooltipProvider>
      </QueryClientProvider>
    </AuthContext.Provider>,
  )
  return userEvent.setup()
}

describe("ResourcePage", () => {
  it("lists rows and shows the empty state", async () => {
    rows = []
    renderPage()
    expect(await screen.findByText("Nenhum curso cadastrado ainda.")).toBeInTheDocument()
  })

  it("creates through the base path and blocks invalid input", async () => {
    const user = renderPage()
    await screen.findByText("Ciência")
    await user.click(screen.getByRole("button", { name: "Novo curso" }))
    const dialog = await screen.findByRole("dialog")
    await user.click(within(dialog).getByRole("button", { name: "Salvar" }))
    expect(await within(dialog).findByText("Campo obrigatório.")).toBeInTheDocument()
    expect(writes()).toEqual([])
    await user.type(within(dialog).getByLabelText("Nome"), " Direito ")
    await user.click(within(dialog).getByRole("button", { name: "Salvar" }))
    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0]).toMatchObject({ method: "POST", body: { name: "Direito" } })
    expect(writes()[0].url).toContain("/tenants/t/courses")
  })

  it("edits with the configured method", async () => {
    const user = renderPage()
    await screen.findByText("Ciência")
    await user.click(screen.getByRole("button", { name: "Editar Ciência" }))
    const dialog = await screen.findByRole("dialog")
    await user.click(within(dialog).getByRole("button", { name: "Salvar" }))
    await waitFor(() => expect(writes()).toHaveLength(1))
    expect(writes()[0]).toMatchObject({ method: "PUT", body: { name: "Ciência", description: "Texto" } })
    expect(writes()[0].url).toContain("/courses/c1")
  })

  it("asks before deleting and accepts an empty response", async () => {
    const user = renderPage()
    await screen.findByText("Ciência")
    await user.click(screen.getByRole("button", { name: "Excluir Ciência" }))
    const dialog = await screen.findByRole("alertdialog")
    expect(writes()).toEqual([])
    await user.click(within(dialog).getByRole("button", { name: "Excluir" }))
    await waitFor(() => expect(writes()[0]).toMatchObject({ method: "DELETE" }))
    expect(await screen.findByText("Registro excluído.")).toBeInTheDocument()
  })
})
