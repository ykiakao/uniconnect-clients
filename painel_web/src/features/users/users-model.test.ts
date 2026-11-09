import { describe, expect, it } from "vitest"

import * as Model from "./users-model"
import type { ManagedUser, UserFormValues } from "./users-model"

const actor = { id: "actor-id", email: "actor@example.invalid", role: "admin" }
const student: ManagedUser = {
  id: "student-id",
  name: "Pessoa sintética",
  email: "student@example.invalid",
  role: "aluno",
  active: true,
  courseId: "course-1",
  registration: "A-1",
  semester: 2,
}
const form = (values: Partial<UserFormValues>): UserFormValues => ({
  name: "",
  email: "",
  password: "",
  role: "aluno",
  courseId: "",
  registration: "",
  semester: "",
  ...values,
})

describe("list path", () => {
  it("carries pagination and only the filters in use", () => {
    expect(Model.buildListPath("tenant-a", { page: 2, search: "", role: "" })).toBe(
      `/tenants/tenant-a/users?page=2&limit=${Model.PAGE_SIZE}`,
    )
    expect(Model.buildListPath("tenant-a", { page: 1, search: " ana & co ", role: "gestor" })).toBe(
      `/tenants/tenant-a/users?page=1&limit=${Model.PAGE_SIZE}&search=ana+%26+co&role=gestor`,
    )
  })

  it("accepts a custom limit for counts", () => {
    expect(Model.buildListPath("t", { page: 1, search: "ana", role: "aluno", limit: 1 })).toBe(
      "/tenants/t/users?page=1&limit=1&search=ana&role=aluno",
    )
  })
})

describe("URL filters", () => {
  it("parses valid values and falls back on invalid ones", () => {
    expect(Model.parseFilters(new URLSearchParams("q=ana&perfil=gestor&pagina=3"))).toEqual({
      search: "ana",
      role: "gestor",
      page: 3,
    })
    expect(Model.parseFilters(new URLSearchParams("perfil=root&pagina=-1"))).toEqual({
      search: "",
      role: "",
      page: 1,
    })
  })

  it("omits defaults from the URL", () => {
    expect(Model.filtersToParams({ search: "", role: "", page: 1 }).toString()).toBe("")
    expect(Model.filtersToParams({ search: "ana", role: "aluno", page: 2 }).toString()).toBe(
      "q=ana&perfil=aluno&pagina=2",
    )
  })
})

describe("permissions", () => {
  it("assignable roles stay strictly below the actor rank", () => {
    expect(Model.assignableRoles("gestor")).toEqual(["aluno", "professor"])
    expect(Model.assignableRoles("coordinator")).toEqual(["aluno", "professor"])
    expect(Model.assignableRoles("admin")).toEqual(["aluno", "professor", "gestor"])
    expect(Model.assignableRoles("owner")).toEqual(["aluno", "professor", "gestor", "admin"])
    expect(Model.assignableRoles("professor")).toEqual([])
  })

  it("an actor cannot manage themselves or anyone of the same rank", () => {
    expect(Model.canManageUser(actor, student)).toBe(true)
    expect(Model.canManageUser(actor, { ...student, id: actor.id })).toBe(false)
    expect(Model.canManageUser(actor, { ...student, email: "ACTOR@example.invalid" })).toBe(false)
    expect(Model.canManageUser(actor, { ...student, role: "admin" })).toBe(false)
    expect(Model.canManageUser({ ...actor, role: "gestor" }, { ...student, role: "gestor" })).toBe(false)
  })
})

describe("form validation", () => {
  it("create requires identity, a strong enough password and a role", () => {
    const errors = Model.validateUserForm(form({ name: " ", email: "bad", password: "short", role: "" }), "create")
    expect(Object.keys(errors).sort()).toEqual(["email", "name", "password", "role"])
    expect(
      Model.validateUserForm(
        form({ name: "Ana", email: "ana@example.invalid", password: "12345678", role: "professor" }),
        "create",
      ),
    ).toEqual({})
  })

  it("edit ignores credentials and validates student fields only for students", () => {
    expect(Model.validateUserForm(form({ name: "Ana", role: "professor", semester: "99" }), "edit")).toEqual({})
    expect(Object.keys(Model.validateUserForm(form({ name: "Ana", semester: "99" }), "edit"))).toEqual(["semester"])
    expect(Object.keys(Model.validateUserForm(form({ name: "Ana", semester: "1.5" }), "edit"))).toEqual(["semester"])
  })
})

describe("payloads", () => {
  it("create normalizes values and omits student fields for other roles", () => {
    expect(
      Model.toCreatePayload(
        form({
          name: " Ana ",
          email: " ANA@Example.Invalid ",
          password: "12345678",
          courseId: "course-1",
          registration: " A-9 ",
          semester: "3",
        }),
      ),
    ).toEqual({
      name: "Ana",
      email: "ana@example.invalid",
      password: "12345678",
      role: "aluno",
      courseId: "course-1",
      registration: "A-9",
      semester: 3,
    })
    expect(
      Model.toCreatePayload(
        form({ name: "Ana", email: "ana@example.invalid", password: "12345678", role: "professor", courseId: "c" }),
      ),
    ).toEqual({ name: "Ana", email: "ana@example.invalid", password: "12345678", role: "professor" })
  })

  it("profile patch sends only what changed and clears emptied fields", () => {
    const same = form({ name: student.name, courseId: "course-1", registration: "A-1", semester: "2" })
    expect(Model.toProfilePatch(student, same)).toEqual({})
    expect(Model.toProfilePatch(student, { ...same, registration: "", semester: "4" })).toEqual({
      registration: null,
      semester: 4,
    })
    expect(Model.toProfilePatch(student, { ...same, role: "professor", courseId: "" })).toEqual({})
    expect(student.registration).toBe("A-1")
  })
})

describe("page info", () => {
  it("describes the visible range and neighbours", () => {
    expect(Model.pageInfo({ page: 2, limit: 20, total: 45 })).toEqual({
      page: 2,
      total: 45,
      from: 21,
      to: 40,
      hasPrev: true,
      hasNext: true,
    })
    expect(Model.pageInfo({ page: 1, limit: 20, total: 0 })).toEqual({
      page: 1,
      total: 0,
      from: 0,
      to: 0,
      hasPrev: false,
      hasNext: false,
    })
  })
})

describe("error messages", () => {
  it("are specific by code and never leak unknown errors", () => {
    expect(Model.errorMessage({ status: 409, code: "USER_ALREADY_EXISTS", message: "x" })).toMatch(/já está vinculad/)
    expect(Model.errorMessage({ status: 403, code: "OTHER", message: "x" })).toMatch(/permissão/)
    expect(Model.errorMessage({ status: null, code: null, message: "Sem conexão." })).toBe("Sem conexão.")
    expect(Model.errorMessage(new TypeError("internal detail"))).toBe(Model.GENERIC_ERROR)
  })
})
