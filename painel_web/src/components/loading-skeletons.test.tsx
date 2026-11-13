import { render, screen } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import { AppShellSkeleton, TableSkeleton } from "./loading-skeletons"

const COLUMNS = [
  { key: "name", header: "Nome", isPrimary: true },
  { key: "status", header: "Situação" },
  { key: "actions", header: "Ações", isActions: true },
]

const skeletonsIn = (container: HTMLElement) => container.querySelectorAll('[data-slot="skeleton"]')

describe("TableSkeleton", () => {
  it("renders one placeholder per cell", () => {
    const { container } = render(<TableSkeleton label="Carregando cursos..." columns={COLUMNS} rows={3} />)

    expect(skeletonsIn(container)).toHaveLength(COLUMNS.length * 3)
  })

  it("announces only the label to assistive technology", () => {
    render(<TableSkeleton label="Carregando cursos..." columns={COLUMNS} />)

    expect(screen.getByRole("status").textContent).toContain("Carregando cursos...")
    expect(screen.queryByRole("table")).toBeNull()
  })

  it("keeps the real column headers visible while loading", () => {
    const { container } = render(<TableSkeleton label="Carregando cursos..." columns={COLUMNS} />)

    expect(container.querySelector("thead")?.textContent).toContain("Nome")
  })
})

describe("AppShellSkeleton", () => {
  it("announces the loading state", () => {
    render(<AppShellSkeleton />)

    expect(screen.getByRole("status").textContent).toContain("Carregando...")
  })
})
