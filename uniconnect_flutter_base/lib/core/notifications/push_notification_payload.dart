class PushNotificationPayload {
  const PushNotificationPayload({
    required this.type,
    this.tenantId,
    this.tenantSlug,
    this.conversationId,
    this.activityId,
    this.noticeId,
    this.gradeId,
    this.classId,
  });

  final String type;
  final String? tenantId;
  final String? tenantSlug;
  final String? conversationId;
  final String? activityId;
  final String? noticeId;
  final String? gradeId;
  final String? classId;

  factory PushNotificationPayload.fromMap(Map<String, dynamic> data) {
    return PushNotificationPayload(
      type: data['type']?.toString() ?? '',
      tenantId: data['tenantId']?.toString(),
      tenantSlug: data['tenantSlug']?.toString(),
      conversationId: data['conversationId']?.toString(),
      activityId: data['activityId']?.toString(),
      noticeId: data['noticeId']?.toString(),
      gradeId: data['gradeId']?.toString(),
      classId: data['classId']?.toString(),
    );
  }
}
