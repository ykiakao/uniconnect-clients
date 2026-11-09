import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter, Route, Routes } from "react-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { InviteAcceptPage, RecoverPasswordPage, SetPasswordPage } from "./public-pages"

type Call = { method: string; url: string; headers: Record<string, string>; body?: unknown }
let calls: Call[] = []

beforeEach(() => {
  calls = []
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, options: RequestInit = {}) => {
      const method = options.method ?? "GET"
      calls.push({
        method,
        url,
        headers: options.headers as Record<string, string>,
        body: options.body ? JSON.parse(String(options.body)) : undefined,
      })
      if (method === "GET") return new Response(JSON.stringify({ tenantName: "EduKMais", role: "aluno" }), { status: 200 })
      if (url.endsWith("/recovery")) return new Response(JSON.stringify({ message: "ok" }), { status: 202 })
      if (url.includes("/invites/")) return new Response(JSON.stringify({}), { status: 201 })
      return new Response(null, { status: 204 })
    }),
  )
})

afterEach(() => vi.unstubAllGlobals())

const posts = () => calls.filter((call) => call.method === "POST")

describe("public access pages", () => {
  it("asks for recovery and answers the same way for any e-mail", async () => {
    const user = userEvent.setup()
    render(
      <MemoryRouter>
        <RecoverPasswordPage />
      </MemoryRouter>,
    )
    await user.type(screen.getByLabelText("E-mail institucional"), "ana@example.invalid")
    await user.click(screen.getByRole("button", { name: "Enviar instruções" }))
    expect(await screen.findByText(/Se a conta puder receber e-mails/)).toBeInTheDocument()
    expect(posts()[0].url).toContain("/auth/password/recovery")
    expect(posts()[0].body).toEqual({ email: "ana@example.invalid" })
    expect(posts()[0].headers.Authorization).toBeUndefined()
  })

  function renderReset(entry: string) {
    render(
      <MemoryRouter initialEntries={[entry]}>
        <Routes>
          <Route path="/password/reset" element={<SetPasswordPage kind="reset" />} />
        </Routes>
      </MemoryRouter>,
    )
    return userEvent.setup()
  }

  it("reads the proof from the fragment and sends it only in the body", async () => {
    const user = renderReset("/password/reset#token_hash=proof-123")
    await user.type(screen.getByLabelText("Nova senha"), "12345678")
    await user.type(screen.getByLabelText("Confirmar senha"), "12345678")
    await user.click(screen.getByRole("button", { name: "Salvar senha" }))
    await waitFor(() => expect(posts()).toHaveLength(1))
    expect(posts()[0].body).toEqual({ tokenHash: "proof-123", newPassword: "12345678" })
    expect(posts()[0].url).not.toContain("proof-123")
  })

  it("rejects a link without proof and mismatched passwords", async () => {
    renderReset("/password/reset")
    expect(screen.getByRole("alert")).toHaveTextContent(/link.*inválido/i)
  })

  it("blocks mismatched passwords", async () => {
    const user = renderReset("/password/reset#token_hash=proof")
    await user.type(screen.getByLabelText("Nova senha"), "12345678")
    await user.type(screen.getByLabelText("Confirmar senha"), "87654321")
    await user.click(screen.getByRole("button", { name: "Salvar senha" }))
    expect(await screen.findByText("As senhas não coincidem.")).toBeInTheDocument()
    expect(posts()).toEqual([])
  })

  it("accepts an invite by creating an account", async () => {
    render(
      <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
        <MemoryRouter initialEntries={["/convites/ABC123"]}>
          <Routes>
            <Route path="/convites/:code" element={<InviteAcceptPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
    const user = userEvent.setup()
    await screen.findByText(/EduKMais/)
    await user.type(screen.getByLabelText("Nome completo"), "Ana")
    await user.type(screen.getByLabelText("E-mail"), "ana@example.invalid")
    await user.type(screen.getByLabelText("Senha"), "12345678")
    await user.click(screen.getByRole("button", { name: "Criar conta" }))
    await waitFor(() => expect(posts()).toHaveLength(1))
    expect(posts()[0].url).toContain("/invites/ABC123/register")
    expect(await screen.findByText(/Acesso ativado/)).toBeInTheDocument()
  })
})
