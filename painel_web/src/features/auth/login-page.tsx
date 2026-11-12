import { useState } from "react"
import { Eye, EyeOff } from "lucide-react"
import { Controller, useForm } from "react-hook-form"
import { Link } from "react-router"

import { safeAuthError, type LoginValues } from "./session"
import { useAuth } from "./use-auth"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { PLACEHOLDERS } from "@/lib/placeholders"

export function LoginPage() {
  const { login, error: sessionError, tenantSlug } = useAuth()
  const [submitError, setSubmitError] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const { register, control, handleSubmit, formState } = useForm<LoginValues>({
    defaultValues: { tenantSlug, email: "", password: "", remember: false },
  })
  const { isSubmitting } = formState
  const error = submitError || sessionError

  const onSubmit = handleSubmit(async (values) => {
    setSubmitError("")
    try {
      await login({
        ...values,
        tenantSlug: values.tenantSlug.trim(),
        email: values.email.trim(),
      })
    } catch (caught) {
      setSubmitError(safeAuthError(caught))
    }
  })

  return (
    <main className="flex min-h-svh flex-col items-center justify-center gap-6 bg-card p-6">
      <div className="flex w-full max-w-sm flex-col gap-6">
        <img src="/brand/uniconnect-logo-vertical.png" alt="UniConnect" className="mx-auto h-24 w-auto" />
        <Card className="bg-background">
          <CardHeader>
            <CardTitle className="text-xl">Portal da coordenação</CardTitle>
            <CardDescription>
              Entrada exclusiva para coordenadores, mantenedores e administradores autorizados.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form className="flex flex-col gap-4" onSubmit={onSubmit}>
              <div className="grid gap-2">
                <Label htmlFor="tenantSlug">Instituição</Label>
                <Input id="tenantSlug" placeholder="Ex.: universidade-exemplo" required disabled={isSubmitting} {...register("tenantSlug")} />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="email">E-mail institucional</Label>
                <Input id="email" type="email" autoComplete="email" placeholder={PLACEHOLDERS.email} required disabled={isSubmitting} {...register("email")} />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="password">Senha</Label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? "text" : "password"}
                    autoComplete="current-password"
                    placeholder={PLACEHOLDERS.currentPassword}
                    required
                    disabled={isSubmitting}
                    className="pr-9"
                    {...register("password")}
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon-sm"
                    className="absolute top-1/2 right-0.5 -translate-y-1/2"
                    aria-label={showPassword ? "Ocultar senha" : "Mostrar senha"}
                    onClick={() => setShowPassword((current) => !current)}
                  >
                    {showPassword ? <EyeOff /> : <Eye />}
                  </Button>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Controller
                  control={control}
                  name="remember"
                  render={({ field }) => (
                    <Checkbox
                      id="remember"
                      checked={field.value}
                      disabled={isSubmitting}
                      onCheckedChange={(checked) => field.onChange(checked === true)}
                    />
                  )}
                />
                <Label htmlFor="remember">Lembrar de mim</Label>
              </div>
              {error && (
                <p role="alert" className="text-sm text-destructive">
                  {error}
                </p>
              )}
              <Button type="submit" disabled={isSubmitting}>
                {isSubmitting ? "Entrando..." : "Entrar"}
              </Button>
              <Link to="/recuperar-senha" className="text-center text-sm font-medium text-primary hover:underline">
                Esqueci minha senha
              </Link>
            </form>
          </CardContent>
        </Card>
        <p className="text-center text-xs text-muted-foreground">
          Use uma credencial administrativa vinculada à instituição.
        </p>
        <p className="text-center text-sm text-muted-foreground">
          É da equipe da plataforma?{" "}
          <Link to="/plataforma" className="font-medium text-primary hover:underline">
            Administração da plataforma
          </Link>
        </p>
      </div>
    </main>
  )
}
