import { render, screen, within } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import { DataTable, type Column } from "./data-table"

type Row = { id: string; name: string; status: string }
const columns: Column<Row>[] = [
  { key: "name", header: "Nome", isPrimary: true, cell: (row) => row.name },
  { key: "status", header: "Status", cell: (row) => row.status },
  { key: "actions", header: "Ações", isActions: true, cell: () => <button type="button">Editar</button> },
]

describe("DataTable", () => {
  it("repeats the column name on secondary cells so rows can stack on small screens", () => {
    render(<DataTable label="Lista" columns={columns} rows={[{ id: "1", name: "Ana", status: "Ativo" }]} getRowKey={(row) => row.id} />)
    const [row] = screen.getAllByRole("row").slice(1)
    const cells = within(row).getAllByRole("cell")
    expect(within(cells[1]).getByText("Status")).toBeInTheDocument()
    expect(within(cells[0]).queryByText("Nome")).not.toBeInTheDocument()
    expect(within(cells[2]).queryByText("Ações")).not.toBeInTheDocument()
  })

  it("exposes the busy state", () => {
    render(<DataTable label="Lista" columns={columns} rows={[]} getRowKey={(row) => row.id} isFetching />)
    expect(screen.getByRole("table", { name: "Lista" })).toHaveAttribute("aria-busy", "true")
  })
})
