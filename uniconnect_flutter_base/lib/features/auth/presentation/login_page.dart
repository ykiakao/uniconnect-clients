import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_banner.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';

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
    if (_isLoading) return;

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
      final user = await ref.read(authControllerProvider.notifier).login(
            email: email,
            password: _passwordController.text,
            rememberSession: _rememberMe,
          );
      if (!mounted) return;
      _goByRole(user);
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
    if (error is ApiException) {
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

  void _goByRole(AppUser user) {
    final route = user.role == UserRole.teacher
        ? AppRoutes.teacherDashboard
        : AppRoutes.studentDashboard;
    context.go(route);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              shrinkWrap: true,
              children: [
                const SizedBox(height: AppSpacing.xl),
                const _BrandMark(),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAAS ACADÊMICO MOBILE-FIRST',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .9,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Bem-vindo de volta',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
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
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                        onChanged: (_) => _clearErrorsOnEdit(),
                        decoration: InputDecoration(
                          labelText: 'E-mail institucional',
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: _emailError,
                          errorMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !_isLoading,
                        onSubmitted: (_) {
                          if (!_isLoading) _login();
                        },
                        onChanged: (_) => _clearErrorsOnEdit(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
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
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          errorText: _passwordError,
                          errorMaxLines: 2,
                        ),
                      ),
                      if (_authError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        StatusBanner(
                          title: 'Falha ao entrar',
                          message: _authError!,
                          tone: AppBadgeTone.danger,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                          ),
                          const Expanded(child: Text('Lembrar de mim')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        onPressed: _isLoading ? null : _login,
                        icon: Icons.login,
                        label: _isLoading ? 'Entrando...' : 'Entrar',
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Use as credenciais institucionais para acessar sua rotina acadêmica.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Português (Brasil)  •  Suporte  •  Privacidade',
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.school, color: Colors.white, size: 38),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'UniConnect',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}
