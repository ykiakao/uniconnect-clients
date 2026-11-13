import { useState } from "react"
import { Copy } from "lucide-react"
import { Controller, useForm } from "react-hook-form"
import { toast } from "sonner"

import { FormError, FormField } from "@/components/page-states"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useApi, useSession } from "@/features/auth/use-auth"
import { ROLE_OPTIONS, assignableRoles, errorMessage } from "@/features/users/users-model"
import { PLACEHOLDERS } from "@/lib/placeholders"

type InviteForm = { recipientEmail: string; role: string; expiresIn: string }
type InviteResult = { code: string; expiresAt?: string }

const DEFAULT_EXPIRATION_DAYS = "7"
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function InvitesPage() {
  const api = useApi()
  const { tenantSlug, user } = useSession()
  const roles = ROLE_OPTIONS.filter((option) => assignableRoles(user.role).includes(option.value))
  const [submitError, setSubmitError] = useState("")
  const [invite, setInvite] = useState<InviteResult | null>(null)
  const { register, control, handleSubmit, formState, reset } = useForm<InviteForm>({
    defaultValues: { recipientEmail: "", role: roles[0]?.value ?? "", expiresIn: DEFAULT_EXPIRATION_DAYS },
  })
  const { errors, isSubmitting } = formState
  const link = invite ? `${window.location.origin}/convites/${encodeURIComponent(invite.code)}` : ""

  const onSubmit = handleSubmit(async (values) => {
    setSubmitError("")
    try {
      const result = await api<InviteResult>(`/tenants/${encodeURIComponent(tenantSlug)}/invites`, {
        method: "POST",
        body: { recipientEmail: values.recipientEmail.trim(), role: values.role, expiresIn: Number(values.expiresIn) },
      })
      setInvite(result)
      reset()
    } catch (error) {
      setSubmitError(errorMessage(error))
    }
  })

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(link)
      toast.success("Link copiado.")
    } catch {
      toast.error("Não foi possível copiar. Selecione o link manualmente.")
    }
  }

  return (
    <div className="grid items-start gap-6 lg:grid-cols-2">
      <Card>
        <CardHeader>
          <CardTitle>Emitir convite</CardTitle>
          <CardDescription>A pessoa usa o link para criar o próprio acesso.</CardDescription>
        </CardHeader>
        <CardContent>
          <form noValidate className="grid gap-4" onSubmit={onSubmit}>
            <FormError message={submitError} />
            <FormField id="invite-email" label="E-mail do destinatário" error={errors.recipientEmail?.message}>
              <Input
                id="invite-email"
                type="email"
                placeholder={PLACEHOLDERS.email}
                autoComplete="off"
                aria-invalid={Boolean(errors.recipientEmail)}
                {...register("recipientEmail", { validate: (value) => EMAIL_PATTERN.test(value.trim()) || "Informe um e-mail válido." })}
              />
            </FormField>
            <div className="grid gap-4 sm:grid-cols-2">
              <FormField id="invite-role" label="Perfil">
                <Controller
                  control={control}
                  name="role"
                  render={({ field }) => (
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger id="invite-role" className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {roles.map((role) => (
                          <SelectItem key={role.value} value={role.value}>
                            {role.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </FormField>
              <FormField id="invite-expires" label="Validade em dias" error={errors.expiresIn?.message}>
                <Input
                  id="invite-expires"
                  type="number"
                  placeholder="De 1 a 30"
                  min={1}
                  max={30}
                  aria-invalid={Boolean(errors.expiresIn)}
                  {...register("expiresIn", { validate: (value) => (Number(value) >= 1 && Number(value) <= 30) || "Informe de 1 a 30 dias." })}
                />
              </FormField>
            </div>
            <Button type="submit" disabled={isSubmitting} className="sm:justify-self-start">
              Emitir convite
            </Button>
          </form>
        </CardContent>
      </Card>

      {invite && (
        <Card>
          <CardHeader>
            <CardTitle>Convite emitido</CardTitle>
            <CardDescription>Envie por um canal privado. Quem tiver o link pode usar o convite, e ele não aparece de novo aqui.</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4">
            <Input readOnly value={link} aria-label="Link do convite" />
            <Button variant="outline" className="sm:justify-self-start" onClick={() => void copyLink()}>
              <Copy />
              Copiar link
            </Button>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
