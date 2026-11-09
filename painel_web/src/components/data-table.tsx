import type { ReactNode } from "react"

import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { cn } from "@/lib/utils"

export type Column<T> = {
  key: string
  header: string
  cell: (row: T) => ReactNode
  /** Main cell of the row: on small screens it shows without the column name. */
  isPrimary?: boolean
  isActions?: boolean
  className?: string
}

type DataTableProps<T> = {
  label: string
  columns: Column<T>[]
  rows: T[]
  getRowKey: (row: T) => string
  isFetching?: boolean
}

/** A regular table on large screens; each row stacks as a card below `lg`. */
export function DataTable<T>({ label, columns, rows, getRowKey, isFetching = false }: DataTableProps<T>) {
  return (
    <Table aria-label={label} aria-busy={isFetching} className={cn("transition-opacity max-lg:block", isFetching && "opacity-60")}>
      <TableHeader className="max-lg:hidden">
        <TableRow>
          {columns.map((column) => (
            <TableHead key={column.key} className={cn("h-11 px-4", column.className)}>
              {column.isActions ? <span className="sr-only">{column.header}</span> : column.header}
            </TableHead>
          ))}
        </TableRow>
      </TableHeader>
      <TableBody className="max-lg:block">
        {rows.map((row) => (
          <TableRow key={getRowKey(row)} className="max-lg:flex max-lg:flex-col max-lg:gap-2 max-lg:p-4">
            {columns.map((column) => (
              <TableCell
                key={column.key}
                className={cn(
                  "px-4 py-3 max-lg:flex max-lg:items-center max-lg:justify-between max-lg:gap-4 max-lg:p-0 max-lg:whitespace-normal",
                  column.isActions && "max-lg:justify-end max-lg:pt-2 max-lg:[&>div]:w-full max-lg:[&>div]:gap-2",
                  column.className,
                )}
              >
                {!column.isPrimary && !column.isActions && (
                  <span className="shrink-0 text-xs text-muted-foreground lg:hidden">{column.header}</span>
                )}
                {column.cell(row)}
              </TableCell>
            ))}
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
