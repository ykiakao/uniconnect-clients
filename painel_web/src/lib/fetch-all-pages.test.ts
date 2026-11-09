import { describe, expect, it, vi } from "vitest"

import { LOOKUP_PAGE_SIZE, fetchAllPages } from "./fetch-all-pages"

const fullPage = Array.from({ length: LOOKUP_PAGE_SIZE }, (_, index) => index)

describe("fetchAllPages", () => {
  it("loads every page until the total is reached", async () => {
    const loadPage = vi.fn(async (page: number) => ({ data: page === 3 ? [1, 2] : fullPage, meta: { total: LOOKUP_PAGE_SIZE * 2 + 2 } }))

    const rows = await fetchAllPages(loadPage)

    expect(rows).toHaveLength(LOOKUP_PAGE_SIZE * 2 + 2)
    expect(loadPage).toHaveBeenCalledTimes(3)
  })

  it("stops when a full page already completes the total", async () => {
    const loadPage = vi.fn(async () => ({ data: fullPage, meta: { total: LOOKUP_PAGE_SIZE } }))

    await fetchAllPages(loadPage)

    expect(loadPage).toHaveBeenCalledTimes(1)
  })

  it("stops on a short page when the API sends no total", async () => {
    const loadPage = vi.fn(async (page: number) => ({ data: page === 1 ? fullPage : [] }))

    const rows = await fetchAllPages(loadPage)

    expect(rows).toHaveLength(LOOKUP_PAGE_SIZE)
    expect(loadPage).toHaveBeenCalledTimes(2)
  })
})
