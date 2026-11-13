import { SidebarHeader } from "@/components/ui/sidebar"
import { cn } from "@/lib/utils"

/** Distância, na logo com 148 px de largura, até o início do texto "UniConnect". */
const WORDMARK_OFFSET = "pl-[50px]"

type SidebarBrandProps = {
  subtitle?: string
}

/** Tem a mesma altura e borda do topo da página, formando uma única faixa. */
export function SidebarBrand({ subtitle }: SidebarBrandProps) {
  return (
    <SidebarHeader className="h-16 shrink-0 justify-center gap-0.5 border-b border-sidebar-border px-4 py-0">
      <img src="/brand/uniconnect-logo-horizontal.png" alt="UniConnect" width={148} height={29} className="h-auto" />
      {subtitle && <span className={cn("truncate text-xs text-muted-foreground", WORDMARK_OFFSET)}>{subtitle}</span>}
    </SidebarHeader>
  )
}
