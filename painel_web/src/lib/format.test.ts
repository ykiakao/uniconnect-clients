import { describe, expect, it } from "vitest"

import { formatPlan, formatStatus } from "./format"

describe("billing labels", () => {
  it("translates the known values", () => {
    expect(formatPlan("growth")).toBe("Growth")
    expect(formatStatus("past_due")).toBe("Pagamento pendente")
  })

  it("never presents an unknown value as a trial or a plan", () => {
    expect(formatStatus("canceled")).toBe("canceled")
    expect(formatPlan("custom")).toBe("custom")
  })

  it("says when the value is missing", () => {
    expect(formatStatus(undefined)).toBe("Não informado")
    expect(formatPlan(undefined)).toBe("Não informado")
  })
})
