import '../../../core/network/api_client.dart';
import '../models/academic_records.dart';

/// Personal academic records: periods, subjects per period and history.
class AcademicRecordsService {
  const AcademicRecordsService(this.client,
      {required this.accessToken, required this.tenantSlug});

  final ApiClient client;
  final String accessToken;
  final String tenantSlug;

  String get _base => '/tenants/${Uri.encodeComponent(tenantSlug)}/academic';

  Future<Map<String, dynamic>> _get(String path,
          [Map<String, String>? query]) =>
      client.get('$_base$path',
          queryParams: query, accessToken: accessToken, tenantSlug: tenantSlug);

  Future<List<AcademicPeriodRef>> periods() async {
    final response = await _get('/periods');
    final rows = response['periods'];
    if (rows is! List) {
      throw const ApiException(
          'A API retornou uma lista de períodos inválida.');
    }
    return List.unmodifiable(rows.map(AcademicPeriodRef.fromJson));
  }

  /// Without [periodId] the API picks the active period.
  Future<AcademicOverviewRecord> overview({String? periodId}) async =>
      AcademicOverviewRecord.fromJson(await _get(
          '/overview', periodId == null ? null : {'periodId': periodId}));

  Future<AcademicHistoryRecord> history() async =>
      AcademicHistoryRecord.fromJson(await _get('/history'));
}
