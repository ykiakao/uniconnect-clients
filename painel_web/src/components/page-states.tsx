import type { ReactNode } from "react"

import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import { pageInfo, type PageMeta } from "@/features/users/users-model"

type StateMessageProps = {
  message: string
  role: "status" | "alert"
  action?: { label: string; onClick: () => void }
}

export function StateMessage({ message, role, action }: StateMessageProps) {
  return (
    <div role={role} className="flex flex-col items-center gap-4 px-6 py-12 text-center text-sm text-muted-foreground">
      <p>{message}</p>
      {action && (
        <Button variant="outline" onClick={action.onClick}>
          {action.label}
        </Button>
      )}
    </div>
  )
}

export function ListPagination({ meta, onPage }: { meta: PageMeta; onPage: (page: number) => void }) {
  const info = pageInfo(meta)
  return (
    <nav aria-label="Paginação" className="flex flex-wrap items-center justify-between gap-4 border-t px-4 py-3">
      <span className="text-sm text-muted-foreground">
        {info.from}–{info.to} de {info.total}
      </span>
      <div className="flex gap-2">
        <Button variant="outline" disabled={!info.hasPrev} onClick={() => onPage(info.page - 1)}>
          Anterior
        </Button>
        <Button variant="outline" disabled={!info.hasNext} onClick={() => onPage(info.page + 1)}>
          Próxima
        </Button>
      </div>
    </nav>
  )
}

type FormFieldProps = { id: string; label: string; error?: string; hint?: string; children: ReactNode }

export function FormField({ id, label, error, hint, children }: FormFieldProps) {
  const message = error ?? hint
  return (
    <div className="grid gap-2">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {message && <p className={error ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{message}</p>}
    </div>
  )
}

export function FormError({ message }: { message: string }) {
  if (!message) return null
  return (
    <p role="alert" className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
      {message}
    </p>
  )
}
