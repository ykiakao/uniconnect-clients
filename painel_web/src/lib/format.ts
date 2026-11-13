const PLAN_LABELS: Record<string, string> = {
  starter: "Starter",
  growth: "Growth",
  enterprise: "Enterprise",
}

const STATUS_LABELS: Record<string, string> = {
  trialing: "Teste ativo",
  active: "Assinatura ativa",
  past_due: "Pagamento pendente",
}

const ADMIN_ROLE_LABELS: Record<string, string> = {
  admin: "Administrador",
  gestor: "Coordenador",
  coordinator: "Coordenador",
  owner: "Mantenedor",
}

const MISSING_LABEL = "Não informado"

export const formatPlan = (plan?: string) => PLAN_LABELS[plan ?? ""] ?? plan ?? MISSING_LABEL
export const formatStatus = (status?: string) => STATUS_LABELS[status ?? ""] ?? status ?? MISSING_LABEL
export const formatAdminRole = (role: string) => ADMIN_ROLE_LABELS[role] ?? "Usuário"
