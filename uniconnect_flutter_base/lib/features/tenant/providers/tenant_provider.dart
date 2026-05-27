import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/tenant_context.dart';

final currentTenantProvider = Provider<TenantContext?>((ref) {
  return ref.watch(currentUserProvider)?.tenant;
});
