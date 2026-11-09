import { useEffect, useState, type ReactNode } from "react"
import { useQuery } from "@tanstack/react-query"
import { useForm } from "react-hook-form"
import { Link, useLocation, useNavigate, useParams } from "react-router"

import { DEFAULT_API_BASE_URL } from "./session"
import { FormSkeleton } from "@/components/loading-skeletons"
import { FormError, FormField } from "@/components/page-states"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { apiRequest } from "@/lib/api-client"
import { errorMessage, roleLabel } from "@/features/users/users-model"
import { PLACEHOLDERS } from "@/lib/placeholders"

const MIN_PASSWORD_LENGTH = 8
const NEW_PASSWORD_PLACEHOLDER = `Mínimo de ${MIN_PASSWORD_LENGTH} caracteres`
const passwordRule = (value: string) => value.length >= MIN_PASSWORD_LENGTH || `Use pelo menos ${MIN_PASSWORD_LENGTH} caracteres.`
const post = (path: string, body: unknown) => apiRequest(path, { baseUrl: DEFAULT_API_BASE_URL, method: "POST", body })

function PublicShell({ title, description, children }: { title: string; description: string; children: ReactNode }) {
  return (
    <main className="flex min-h-svh flex-col items-center justify-center gap-6 bg-card p-6">
      <div className="flex w-full max-w-md flex-col gap-6">
        <img src="/brand/uniconnect-logo-vertical.png" alt="UniConnect" className="mx-auto h-24 w-auto" />
        <Card className="bg-background">
          <CardHeader>
            <CardTitle className="text-xl">{title}</CardTitle>
            <CardDescription>{description}</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4">{children}</CardContent>
        </Card>
      </div>
    </main>
  )
}

const BackToLogin = () => (
  <Link to="/" className="text-sm font-medium text-primary hover:underline">
    Voltar para o login
  </Link>
)

function Done({ message }: { message: string }) {
  return (
    <>
      <p role="status" className="text-sm">
        {message}
      </p>
      <BackToLogin />
    </>
  )
}

export function RecoverPasswordPage() {
  const [isDone, setIsDone] = useState(false)
  const [submitError, setSubmitError] = useState("")
  const { register, handleSubmit, formState } = useForm<{ email: string }>({ defaultValues: { email: "" } })

  const onSubmit = handleSubmit(async ({ email }) => {
    setSubmitError("")
    try {
      await post("/auth/password/recovery", { email: email.trim() })
      setIsDone(true)
    } catch (error) {
      setSubmitError(errorMessage(error))
    }
  })

  return (
    <PublicShell title="Recuperar senha" description="Informe seu e-mail para receber as instruções.">
      {isDone ? (
        <Done message="Se a conta puder receber e-mails, enviaremos as instruções de recuperação." />
      ) : (
        <form className="grid gap-4" onSubmit={onSubmit}>
          <FormError message={submitError} />
          <FormField id="recover-email" label="E-mail institucional">
            <Input id="recover-email" type="email" placeholder={PLACEHOLDERS.email} required autoComplete="email" {...register("email", { required: true })} />
          </FormField>
          <Button type="submit" disabled={formState.isSubmitting}>
            Enviar instruções
          </Button>
          <BackToLogin />
        </form>
      )}
    </PublicShell>
  )
}

type SetPasswordForm = { newPassword: string; confirmation: string }

const SET_PASSWORD_COPY = {
  reset: { title: "Redefinir senha", description: "Crie uma nova senha para sua conta.", path: "/auth/password/reset", done: "Senha alterada. Entre com a nova senha." },
  activate: { title: "Ativar conta", description: "Defina a senha do seu primeiro acesso.", path: "/auth/accounts/activate", done: "Conta ativada. Entre com a senha que você criou." },
}

export function SetPasswordPage({ kind }: { kind: "reset" | "activate" }) {
  const copy = SET_PASSWORD_COPY[kind]
  const { hash, pathname } = useLocation()
  const navigate = useNavigate()
  const [tokenHash] = useState(() => {
    const params = new URLSearchParams(hash.slice(1))
    return params.get("token_hash") ?? params.get("tokenHash") ?? ""
  })
  const [isDone, setIsDone] = useState(false)
  const [submitError, setSubmitError] = useState("")
  const { register, handleSubmit, getValues, formState } = useForm<SetPasswordForm>({ defaultValues: { newPassword: "", confirmation: "" } })
  const { errors } = formState

  // The proof must not stay in the address bar or browser history.
  useEffect(() => {
    if (hash) navigate(pathname, { replace: true })
  }, [hash, pathname, navigate])

  const onSubmit = handleSubmit(async ({ newPassword }) => {
    setSubmitError("")
    try {
      await post(copy.path, { tokenHash, newPassword })
      setIsDone(true)
    } catch (error) {
      setSubmitError(errorMessage(error))
    }
  })

  function renderBody() {
    if (!tokenHash) {
      return (
        <>
          <p role="alert" className="text-sm text-destructive">
            Este link é inválido ou está incompleto. Solicite um novo.
          </p>
          <BackToLogin />
        </>
      )
    }
    if (isDone) return <Done message={copy.done} />
    return (
      <form noValidate className="grid gap-4" onSubmit={onSubmit}>
        <FormError message={submitError} />
        <FormField id="new-password" label="Nova senha" error={errors.newPassword?.message}>
          <Input id="new-password" type="password" placeholder={NEW_PASSWORD_PLACEHOLDER} autoComplete="new-password" aria-invalid={Boolean(errors.newPassword)} {...register("newPassword", { validate: passwordRule })} />
        </FormField>
        <FormField id="confirm-password" label="Confirmar senha" error={errors.confirmation?.message}>
          <Input
            id="confirm-password"
            type="password"
            placeholder="Repita a nova senha"
            autoComplete="new-password"
            aria-invalid={Boolean(errors.confirmation)}
            {...register("confirmation", { validate: (value) => value === getValues("newPassword") || "As senhas não coincidem." })}
          />
        </FormField>
        <Button type="submit" disabled={formState.isSubmitting}>
          Salvar senha
        </Button>
      </form>
    )
  }

  return (
    <PublicShell title={copy.title} description={copy.description}>
      {renderBody()}
    </PublicShell>
  )
}

type InviteInfo = { tenantName?: string; tenant?: { name?: string }; role?: string }
type InviteForm = { name: string; email: string; password: string }

export function InviteAcceptPage() {
  const { code = "" } = useParams()
  const path = `/invites/${encodeURIComponent(code)}`
  const [hasAccount, setHasAccount] = useState(false)
  const [isDone, setIsDone] = useState(false)
  const [submitError, setSubmitError] = useState("")
  const { register, handleSubmit, formState } = useForm<InviteForm>({ defaultValues: { name: "", email: "", password: "" } })
  const { errors } = formState
  const invite = useQuery({
    queryKey: ["invite", code],
    queryFn: () => apiRequest<InviteInfo>(path, { baseUrl: DEFAULT_API_BASE_URL }),
  })
  const institution = invite.data?.tenantName ?? invite.data?.tenant?.name ?? "a instituição"

  const onSubmit = handleSubmit(async (values) => {
    setSubmitError("")
    try {
      await post(`${path}/${hasAccount ? "login" : "register"}`, { ...values, name: values.name.trim(), email: values.email.trim() })
      setIsDone(true)
    } catch (error) {
      setSubmitError(errorMessage(error))
    }
  })

  function renderBody() {
    if (invite.isError) {
      return (
        <>
          <p role="alert" className="text-sm text-destructive">
            Este convite é inválido ou expirou. Peça um novo à instituição.
          </p>
          <BackToLogin />
        </>
      )
    }
    if (invite.isPending) return <FormSkeleton label="Carregando convite..." />
    if (isDone) return <Done message="Acesso ativado. Entre com seu e-mail e senha." />
    return (
      <form noValidate className="grid gap-4" onSubmit={onSubmit}>
        <FormError message={submitError} />
        <p className="text-sm">
          Você foi convidado para <strong>{institution}</strong>
          {invite.data.role ? ` como ${roleLabel(invite.data.role)}` : ""}.
        </p>
        <FormField id="invite-name" label="Nome completo" error={errors.name?.message}>
          <Input id="invite-name" autoComplete="name" placeholder={PLACEHOLDERS.personName} aria-invalid={Boolean(errors.name)} {...register("name", { validate: (value) => Boolean(value.trim()) || "Informe o nome." })} />
        </FormField>
        <FormField id="invite-email" label="E-mail" hint="Use o e-mail que recebeu o convite." error={errors.email?.message}>
          <Input id="invite-email" type="email" placeholder={PLACEHOLDERS.email} autoComplete="email" aria-invalid={Boolean(errors.email)} {...register("email", { validate: (value) => Boolean(value.trim()) || "Informe o e-mail." })} />
        </FormField>
        <FormField id="invite-password" label="Senha" error={errors.password?.message}>
          <Input id="invite-password" type="password" placeholder={hasAccount ? PLACEHOLDERS.currentPassword : NEW_PASSWORD_PLACEHOLDER} autoComplete={hasAccount ? "current-password" : "new-password"} aria-invalid={Boolean(errors.password)} {...register("password", { validate: passwordRule })} />
        </FormField>
        <Button type="submit" disabled={formState.isSubmitting}>
          {hasAccount ? "Entrar e aceitar" : "Criar conta"}
        </Button>
        <Button type="button" variant="link" onClick={() => setHasAccount((current) => !current)}>
          {hasAccount ? "Ainda não tenho conta" : "Já tenho conta"}
        </Button>
      </form>
    )
  }

  return (
    <PublicShell title="Aceitar convite" description="Crie seu acesso ao UniConnect.">
      {renderBody()}
    </PublicShell>
  )
}
