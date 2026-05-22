import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Email é obrigatório';
    }
    if (!email.contains('@')) {
      return 'Email inválido';
    }
    if (!email.endsWith('@uni.com')) {
      return 'Use email institucional (@uni.com)';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Senha é obrigatória';
    }
    if (password.length < 6) {
      return 'Mínimo 6 caracteres';
    }
    return null;
  }

  void _login() {
    final emailError = _validateEmail(_emailController.text);
    final passwordError = _validatePassword(_passwordController.text);

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });

    if (emailError != null || passwordError != null) {
      return;
    }

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
      body: Center(
        child: SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UniConnect',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Dados acadêmicos em ações claras.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.84),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppCard(
                  backgroundColor: AppColors.secondarySoft,
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined,
                          color: AppColors.secondary),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Use aluno@uni.com ou professor@uni.com para navegar pelo MVP.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
                    labelText: 'Email institucional',
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _emailError,
                    errorMaxLines: 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _login,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_isLoading ? 'Entrando...' : 'Entrar'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _googleLogin,
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text('Login Google'),
                ),
                const SizedBox(height: AppSpacing.xl * 1.5),
                Center(
                  child: Text(
                    'Português (Brasil) • Suporte • Privacidade',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
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
