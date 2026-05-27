class CareCustomRitual {
  const CareCustomRitual({
    required this.id,
    required this.title,
    required this.encryptedPayload,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String encryptedPayload;
  final DateTime createdAt;
}
