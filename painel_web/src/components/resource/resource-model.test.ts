import { describe, expect, it } from "vitest"

import * as R from "./resource-model"
import type { ResourceField } from "./resource-model"

const fields: ResourceField[] = [
  { name: "code", label: "Código", required: true, pattern: { regex: /^[A-Z0-9-]+$/, message: "Código inválido." } },
  { name: "name", label: "Nome", required: true, maxLength: 5 },
  { name: "startDate", label: "Início", type: "date", clearable: true },
  { name: "status", label: "Status", type: "select", defaultValue: "active", options: [{ value: "active", label: "Ativo" }] },
  { name: "parentId", label: "Pai", createOnly: true, required: true },
  { name: "courseId", label: "Curso", required: true, visibleWhen: (values) => values.kind === "course" },
]

const row = { id: "1", code: "AB", name: "Ana", startDate: "2026-01-01", status: "active", parentId: "p" }

describe("resource list path", () => {
  it("keeps pagination and only filled filters", () => {
    expect(R.buildListPath("/tenants/t/subjects", { page: 2, filters: { courseId: "c", status: "" } })).toBe(
      `/tenants/t/subjects?page=2&limit=${R.PAGE_SIZE}&courseId=c`,
    )
  })
})

describe("resource form", () => {
  it("starts from the row or the default", () => {
    expect(R.initialValues(fields, null)).toMatchObject({ code: "", status: "active" })
    expect(R.initialValues(fields, row)).toMatchObject({ code: "AB", name: "Ana" })
  })

  it("validates required, length and pattern on active fields only", () => {
    const empty = R.initialValues(fields, null)
    expect(Object.keys(R.validate(fields, empty, "create")).sort()).toEqual(["code", "name", "parentId"])
    expect(Object.keys(R.validate(fields, { ...empty, kind: "course" }, "create"))).toContain("courseId")
    expect(Object.keys(R.validate(fields, empty, "edit"))).not.toContain("parentId")
    expect(R.validate(fields, { ...empty, code: "a b", name: "longo demais", parentId: "p" }, "create")).toEqual({
      code: "Código inválido.",
      name: "Use no máximo 5 caracteres.",
    })
  })

  it("create payload trims and omits empty and hidden values", () => {
    expect(
      R.toFullPayload(fields, { code: " AB ", name: "Ana", startDate: "", status: "active", parentId: "p", courseId: "x" }, "create"),
    ).toEqual({ code: "AB", name: "Ana", status: "active", parentId: "p" })
  })

  it("changed payload sends only differences and clears clearable fields", () => {
    const same = R.initialValues(fields, row)
    expect(R.toChangedPayload(fields, same, row)).toEqual({})
    expect(R.toChangedPayload(fields, { ...same, name: "Bia", startDate: "" }, row)).toEqual({ name: "Bia", startDate: null })
    expect(R.toChangedPayload(fields, { ...same, parentId: "other" }, row)).toEqual({})
  })

  it("resolves dependent options", () => {
    const field: ResourceField = {
      name: "subjectId",
      label: "Disciplina",
      options: (values) => (values.courseId ? [{ value: "s", label: "S" }] : []),
    }
    expect(R.resolveOptions(field, { courseId: "c" })).toHaveLength(1)
    expect(R.resolveOptions(field, {})).toHaveLength(0)
  })
})
