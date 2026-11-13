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

  Future<List<AcademicTermDates>> activeTermDates() async {
    const invalid =
        ApiException('A API retornou uma lista de períodos inválida.');
    final terms = <AcademicTermDates>[];
    for (var page = 1; page <= 100; page++) {
      final response = await client.get(
        '/tenants/${Uri.encodeComponent(tenantSlug)}/academic-periods',
        queryParams: {'status': 'active', 'page': '$page', 'limit': '100'},
        accessToken: accessToken,
        tenantSlug: tenantSlug,
      );
      final data = response['data'];
      final meta = response['meta'];
      if (data is! List ||
          data.length > 100 ||
          meta is! Map<String, dynamic> ||
          meta['page'] != page ||
          meta['limit'] != 100 ||
          meta['total'] is! int ||
          (meta['total'] as int) < 0) {
        throw invalid;
      }
      terms.addAll(data.map(AcademicTermDates.fromJson));
      if (terms.length > (meta['total'] as int)) throw invalid;
      if (terms.length == (meta['total'] as int)) {
        return List.unmodifiable(terms);
      }
      if (data.length < 100) throw invalid;
    }
    throw invalid;
  }
}
