import type { ReactNode } from "react"

import { DataTable, type Column } from "@/components/data-table"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { cn } from "@/lib/utils"

const DEFAULT_TABLE_ROWS = 5
const SHELL_NAV_ITEMS = 8
const CELL_WIDTHS = ["w-40", "w-24", "w-28", "w-16"]
const LINE_WIDTHS = ["w-full", "w-5/6", "w-2/3"]

const range = (length: number) => Array.from({ length }, (_, index) => index)

type LabelProps = { label: string }
type SkeletonColumn = Pick<Column<number>, "key" | "header" | "isPrimary" | "isActions" | "className">

/** Leitores de tela ouvem só o texto; as formas animadas ficam ocultas para eles. */
function LoadingRegion({ label, children }: LabelProps & { children: ReactNode }) {
  return (
    <div role="status" aria-busy="true">
      <span className="sr-only">{label}</span>
      <div aria-hidden="true">{children}</div>
    </div>
  )
}

function Lines({ count }: { count: number }) {
  return (
    <div className="grid gap-3">
      {range(count).map((index) => (
        <Skeleton key={index} className={cn("h-4", LINE_WIDTHS[index % LINE_WIDTHS.length])} />
      ))}
    </div>
  )
}

/** Usa a própria DataTable, então colunas e versão mobile ficam iguais às da lista real. */
export function TableSkeleton({ label, columns, rows = DEFAULT_TABLE_ROWS }: LabelProps & { columns: SkeletonColumn[]; rows?: number }) {
  const placeholderColumns: Column<number>[] = columns.map(({ key, header, isPrimary, isActions, className }, index) => ({
    key,
    header,
    isPrimary,
    isActions,
    className,
    cell: () =>
      isActions ? <Skeleton className="ml-auto size-8 max-lg:h-9" /> : <Skeleton className={cn("h-4 max-w-full", CELL_WIDTHS[index % CELL_WIDTHS.length])} />,
  }))

  return (
    <LoadingRegion label={label}>
      <DataTable label={label} columns={placeholderColumns} rows={range(rows)} getRowKey={String} />
    </LoadingRegion>
  )
}

export function MetricCardsSkeleton({ label, count = 4 }: LabelProps & { count?: number }) {
  return (
    <LoadingRegion label={label}>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {range(count).map((index) => (
          <Card key={index}>
            <CardHeader>
              <Skeleton className="h-4 w-24" />
              <Skeleton className="h-9 w-16" />
            </CardHeader>
          </Card>
        ))}
      </div>
    </LoadingRegion>
  )
}

export function ChartSkeleton({ label }: LabelProps) {
  return (
    <LoadingRegion label={label}>
      <Skeleton className="h-48 w-full" />
    </LoadingRegion>
  )
}

export function LinesSkeleton({ label, lines = 3 }: LabelProps & { lines?: number }) {
  return (
    <LoadingRegion label={label}>
      <Lines count={lines} />
    </LoadingRegion>
  )
}

export function FormSkeleton({ label, fields = 3 }: LabelProps & { fields?: number }) {
  return (
    <LoadingRegion label={label}>
      <div className="grid gap-4">
        <Skeleton className="h-4 w-5/6" />
        {range(fields).map((index) => (
          <div key={index} className="grid gap-2">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-9 w-full" />
          </div>
        ))}
        <Skeleton className="h-9 w-full" />
      </div>
    </LoadingRegion>
  )
}

export function SectionsSkeleton({ label, count = 3 }: LabelProps & { count?: number }) {
  return (
    <LoadingRegion label={label}>
      <div className="flex flex-col gap-6">
        {range(count).map((index) => (
          <Card key={index}>
            <CardHeader>
              <Skeleton className="h-5 w-48" />
              <Skeleton className="h-4 w-64 max-w-full" />
            </CardHeader>
            <CardContent>
              <Lines count={2} />
            </CardContent>
          </Card>
        ))}
      </div>
    </LoadingRegion>
  )
}

/** Tela inteira enquanto a sessão é restaurada, antes de o menu real existir. */
export function AppShellSkeleton() {
  return (
    <LoadingRegion label="Carregando...">
      <div className="flex min-h-svh">
        <div className="hidden w-64 shrink-0 flex-col border-r border-sidebar-border bg-sidebar md:flex">
          <div className="flex h-16 items-center border-b border-sidebar-border px-4">
            <Skeleton className="h-7 w-36" />
          </div>
          <div className="grid gap-3 p-4">
            {range(SHELL_NAV_ITEMS).map((index) => (
              <Skeleton key={index} className="h-6 w-full" />
            ))}
          </div>
        </div>
        <div className="flex min-w-0 flex-1 flex-col">
          <div className="flex h-16 shrink-0 items-center gap-3 border-b px-4 md:px-6">
            <Skeleton className="size-8" />
            <Skeleton className="h-5 w-40" />
          </div>
          <div className="flex flex-1 flex-col gap-6 p-4 md:p-6">
            <Skeleton className="h-9 w-full max-w-sm" />
            <Skeleton className="h-72 w-full rounded-xl" />
          </div>
        </div>
      </div>
    </LoadingRegion>
  )
}
