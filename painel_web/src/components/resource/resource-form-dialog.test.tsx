import { render, screen } from "@testing-library/react"
import { describe, expect, it, vi } from "vitest"

import { ResourceFormDialog } from "./resource-form-dialog"
import type { ResourceField } from "./resource-model"

const FIELDS: ResourceField[] = [
  { name: "name", label: "Nome", placeholder: "Ex.: Cálculo I" },
  { name: "description", label: "Descrição", type: "textarea", placeholder: "Descreva o curso" },
]

describe("ResourceFormDialog", () => {
  it("shows each field's placeholder on inputs and textareas", () => {
    render(<ResourceFormDialog title="Novo" fields={FIELDS} mode="create" row={null} onSubmit={vi.fn()} onClose={vi.fn()} />)

    expect((screen.getByLabelText("Nome") as HTMLInputElement).placeholder).toBe("Ex.: Cálculo I")
    expect((screen.getByLabelText("Descrição") as HTMLTextAreaElement).placeholder).toBe("Descreva o curso")
  })
})
