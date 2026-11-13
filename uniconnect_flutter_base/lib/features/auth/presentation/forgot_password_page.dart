import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/status_banner.dart';
import '../providers/auth_provider.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Informe um e-mail válido.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(apiAuthServiceProvider).requestPasswordRecovery(email);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível enviar agora. Confira sua conexão e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              children: [
                const BrandLogo(height: 80),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Recuperar senha', style: text.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                          'Informe seu e-mail institucional. Se ele estiver cadastrado, você recebe as instruções para criar uma nova senha.',
                          style: text.bodyMedium
                              ?.copyWith(color: AppColors.inkMuted)),
                      const SizedBox(height: AppSpacing.lg),
                      if (_sent)
                        const StatusBanner(
                          title: 'Pedido enviado',
                          message:
                              'Se a conta puder receber e-mails, enviaremos as instruções em instantes. Confira também a caixa de spam.',
                          tone: AppBadgeTone.success,
                        )
                      else ...[
                        TextField(
                          controller: _email,
                          enabled: !_sending,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'E-mail institucional',
                            prefixIcon: const Icon(LucideIcons.mail),
                            errorText: _error,
                            errorMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Enviar instruções',
                          icon: LucideIcons.send,
                          isLoading: _sending,
                          onPressed: _sending ? null : _submit,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    style: AppButtonStyles.link,
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Voltar para o login'),
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
