class CareEncryptedPayload {
  const CareEncryptedPayload({
    required this.algorithm,
    required this.nonceBase64,
    required this.cipherTextBase64,
    required this.macBase64,
  });

  final String algorithm;
  final String nonceBase64;
  final String cipherTextBase64;
  final String macBase64;

  factory CareEncryptedPayload.fromJson(Map<String, dynamic> json) {
    return CareEncryptedPayload(
      algorithm: json['algorithm']?.toString() ?? '',
      nonceBase64: json['nonceBase64']?.toString() ?? '',
      cipherTextBase64: json['cipherTextBase64']?.toString() ?? '',
      macBase64: json['macBase64']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'algorithm': algorithm,
      'nonceBase64': nonceBase64,
      'cipherTextBase64': cipherTextBase64,
      'macBase64': macBase64,
    };
  }
}
