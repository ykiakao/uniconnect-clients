import { render, screen } from "@testing-library/react"
import { MemoryRouter } from "react-router"
import { describe, expect, it, vi } from "vitest"

import { LoginPage } from "./login-page"

vi.mock("./use-auth", () => ({
  useAuth: () => ({ login: vi.fn(), error: "", apiBaseUrl: "http://api.invalid/api/v1", tenantSlug: "edukmais" }),
}))

describe("LoginPage", () => {
  it("links to the platform administration login", () => {
    render(
      <MemoryRouter>
        <LoginPage />
      </MemoryRouter>,
    )

    expect(screen.getByRole("link", { name: "Administração da plataforma" }).getAttribute("href")).toBe("/plataforma")
  })
})
