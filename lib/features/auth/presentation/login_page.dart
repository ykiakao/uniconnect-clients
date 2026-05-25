import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController(text: 'aluno@uni.com');
  final _passwordController = TextEditingController(text: '123456');
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  bool _rememberMe = true;

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email é obrigatório';
    if (!email.contains('@')) return 'Email inválido';
    if (!email.endsWith('@uni.com')) {
      return 'Use email institucional (@uni.com)';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Senha é obrigatória';
    if (password.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  void _login() {
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });

    if (emailError != null || passwordError != null) return;

    setState(() => _isLoading = true);
    ref.read(authControllerProvider.notifier).login(_emailController.text);
    _goByRole(ref.read(authControllerProvider)!);
  }

  void _googleLogin() {
    setState(() => _isLoading = true);
    ref.read(authControllerProvider.notifier).loginWithGoogleMock();
    _goByRole(ref.read(authControllerProvider)!);
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
                        'PORTAL ACADÊMICO',
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
                        'Insira suas credenciais para acessar sua conta.',
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
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Email Institucional',
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: _emailError,
                          errorMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        enabled: !_isLoading,
                        onSubmitted: (_) => _isLoading ? null : _login(),
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: _passwordError,
                          errorMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() => _rememberMe = value ?? false);
                            },
                          ),
                          const Expanded(child: Text('Lembrar de mim')),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Esqueci minha senha'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        onPressed: _isLoading ? null : _login,
                        icon: Icons.login,
                        label: _isLoading ? 'Entrando...' : 'Entrar',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _DividerLabel(label: 'OU ENTRE COM'),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              onPressed: _isLoading ? null : _googleLogin,
                              icon: Icons.g_mobiledata,
                              label: 'Google',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: SecondaryButton(
                              onPressed: _isLoading ? null : _login,
                              icon: Icons.verified_user_outlined,
                              label: 'SSO',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Use aluno@uni.com ou professor@uni.com para navegar pelo MVP.',
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

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
