enum SubscriptionPlan { starter, growth, enterprise }

enum SubscriptionStatus { trialing, active, pastDue }

class TenantContext {
  const TenantContext({
    required this.id,
    required this.name,
    required this.slug,
    required this.plan,
    required this.status,
    required this.activeUsers,
  });

  final String id;
  final String name;
  final String slug;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final int activeUsers;

  factory TenantContext.fromJson(Map<String, dynamic> json) {
    return TenantContext(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      plan: SubscriptionPlanX.fromApi(json['plan'] as String),
      status: SubscriptionStatusX.fromApi(json['status'] as String),
      activeUsers: json['activeUsers'] as int,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get planLabel {
    return switch (plan) {
      SubscriptionPlan.starter => 'Starter',
      SubscriptionPlan.growth => 'Growth',
      SubscriptionPlan.enterprise => 'Enterprise',
    };
  }

  String get statusLabel {
    return switch (status) {
      SubscriptionStatus.trialing => 'Teste ativo',
      SubscriptionStatus.active => 'Assinatura ativa',
      SubscriptionStatus.pastDue => 'Pagamento pendente',
    };
  }
}

extension SubscriptionPlanX on SubscriptionPlan {
  static SubscriptionPlan fromApi(String value) {
    return switch (value) {
      'starter' => SubscriptionPlan.starter,
      'growth' => SubscriptionPlan.growth,
      'enterprise' => SubscriptionPlan.enterprise,
      _ => SubscriptionPlan.starter,
    };
  }
}

extension SubscriptionStatusX on SubscriptionStatus {
  static SubscriptionStatus fromApi(String value) {
    return switch (value) {
      'trialing' => SubscriptionStatus.trialing,
      'active' => SubscriptionStatus.active,
      'past_due' => SubscriptionStatus.pastDue,
      _ => SubscriptionStatus.trialing,
    };
  }
}
