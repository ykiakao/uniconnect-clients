import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { describe, expect, it } from "vitest"

import { AuthProvider } from "./auth-provider"
import { useAuth } from "./use-auth"

function LogoutButton() {
  const { status, logout } = useAuth()
  return <button onClick={logout}>{status}</button>
}

describe("AuthProvider", () => {
  it("removes cached data on logout", async () => {
    const client = new QueryClient()
    render(
      <QueryClientProvider client={client}>
        <AuthProvider>
          <LogoutButton />
        </AuthProvider>
      </QueryClientProvider>,
    )
    const button = await screen.findByRole("button", { name: "anonymous" })
    client.setQueryData(["users", "t"], [{ id: "1" }])

    await userEvent.setup().click(button)

    expect(client.getQueryData(["users", "t"])).toBeUndefined()
  })
})
