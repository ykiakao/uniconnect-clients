import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_banner.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../services/session_storage.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/app_button_styles.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _authError;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Informe seu e-mail.';
    if (!email.contains('@')) return 'Informe um e-mail válido.';
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Informe sua senha.';
    return null;
  }

  Future<void> _login() async {
    if (_isLoading || ref.read(authControllerProvider).isRestoring) return;

    final email = _emailController.text.trim().toLowerCase();
    final emailError = _validateEmail(email);
    final passwordError = _validatePassword(_passwordController.text);

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _authError = null;
    });

    if (emailError != null || passwordError != null) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authControllerProvider.notifier).login(
            email: email,
            password: _passwordController.text,
            rememberSession: _rememberMe,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _authError = _loginErrorMessage(error);
      });
    }
  }

  void _clearErrorsOnEdit() {
    if (_emailError != null || _passwordError != null || _authError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
        _authError = null;
      });
    }
  }

  String _loginErrorMessage(Object error) {
    if (error is UnsupportedUserRole) return error.message;
    if (error is ApiException) {
      if (error.code == 'SESSION_STORAGE_UNAVAILABLE') {
        return sessionStorageUnavailableMessage;
      }
      return switch (error.statusCode) {
        401 =>
          'E-mail ou senha incorretos. Confira os dados e tente novamente.',
        403 => 'Usuário não vinculado à instituição.',
        404 => 'Instituição não encontrada.',
        500 => 'Serviço indisponível no momento. Tente novamente em instantes.',
        null =>
          'Não foi possível conectar à API. Verifique sua conexão ou tente novamente.',
        _ => 'Não foi possível entrar. Tente novamente em instantes.',
      };
    }

    return 'Não foi possível conectar à API. Verifique sua conexão ou tente novamente.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final authError = _authError ??
        (auth.status == AuthStatus.unauthenticated ? auth.errorMessage : null);
    final busy = _isLoading || auth.isRestoring;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              shrinkWrap: true,
              children: [
                const SizedBox(height: AppSpacing.xl),
                const BrandLogo(),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEU AMBIENTE ACADÊMICO',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Bem-vindo de volta',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Acesse sua instituição, turmas e rotina acadêmica.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                        onChanged: (_) => _clearErrorsOnEdit(),
                        decoration: InputDecoration(
                          labelText: 'E-mail institucional',
                          prefixIcon: const Icon(LucideIcons.mail),
                          errorText: _emailError,
                          errorMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        enabled: !_isLoading,
                        onSubmitted: (_) {
                          if (!_isLoading) _login();
                        },
                        onChanged: (_) => _clearErrorsOnEdit(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(LucideIcons.lock),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                            ),
                          ),
                          errorText: _passwordError,
                          errorMaxLines: 2,
                        ),
                      ),
                      if (authError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        StatusBanner(
                          title: 'Falha ao entrar',
                          message: authError,
                          tone: AppBadgeTone.danger,
                        ),
                      ],
                      if (auth.canRetryRestore && !busy)
                        TextButton(
                          style: AppButtonStyles.link,
                          onPressed: () {
                            setState(() => _authError = null);
                            ref
                                .read(authControllerProvider.notifier)
                                .restoreSession();
                          },
                          child: const Text('Tentar restaurar sessão'),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      // The whole row is the 48px touch target, so the box
                      // itself can line up with the left edge of the fields.
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: _isLoading
                            ? null
                            : () => setState(() => _rememberMe = !_rememberMe),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              minHeight: AppSizes.touchTarget),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _rememberMe,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(
                                      horizontal: -4, vertical: -4),
                                  onChanged: _isLoading
                                      ? null
                                      : (value) => setState(
                                          () => _rememberMe = value ?? false),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              const Expanded(child: Text('Lembrar de mim')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        onPressed: busy ? null : _login,
                        icon: LucideIcons.logIn,
                        label: auth.isRestoring
                            ? 'Restaurando...'
                            : _isLoading
                                ? 'Entrando...'
                                : 'Entrar',
                        isLoading: busy,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton(
                          style: AppButtonStyles.link,
                          onPressed: busy
                              ? null
                              : () => GoRouter.maybeOf(context)
                                  ?.go(AppRoutes.forgotPassword),
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Use as credenciais institucionais para acessar sua rotina acadêmica.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'UniConnect • Conectando sua rotina acadêmica',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
