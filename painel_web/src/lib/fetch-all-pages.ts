export const LOOKUP_PAGE_SIZE = 100
const MAX_LOOKUP_PAGES = 200

export type PageResult<T> = { data?: T[]; meta?: { total?: number } }

/** A API devolve no máximo 100 itens por página, e os seletores precisam da lista completa. */
export async function fetchAllPages<T>(loadPage: (page: number) => Promise<PageResult<T>>): Promise<T[]> {
  const collect = async (page: number, rows: T[]): Promise<T[]> => {
    const { data = [], meta } = await loadPage(page)
    const all = [...rows, ...data]
    const isLastPage = data.length < LOOKUP_PAGE_SIZE || all.length >= (meta?.total ?? Infinity) || page >= MAX_LOOKUP_PAGES
    return isLastPage ? all : collect(page + 1, all)
  }
  return collect(1, [])
}
