import { render, screen, within } from "@testing-library/react"
import { Pencil } from "lucide-react"
import { describe, expect, it, vi } from "vitest"

import { IconAction } from "./resource-page"
import { TooltipProvider } from "@/components/ui/tooltip"

describe("IconAction", () => {
  it("keeps the full accessible name and carries the short text used as a button on small screens", () => {
    render(
      <TooltipProvider>
        <IconAction label="Editar Banco de Dados" tooltip="Editar" onClick={vi.fn()}>
          <Pencil />
        </IconAction>
      </TooltipProvider>,
    )

    const button = screen.getByRole("button", { name: "Editar Banco de Dados" })
    expect(within(button).getByText("Editar")).toBeTruthy()
  })
})
