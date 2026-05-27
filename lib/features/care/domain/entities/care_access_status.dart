enum CareAccessStatus {
  idle,
  generating,
  active,
  connected,
  syncing,
  expired,
  revoked,
  revoking,
  failure;

  bool get isTerminal => this == expired || this == revoked || this == failure;

  static CareAccessStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ACTIVE' => CareAccessStatus.active,
      'CLAIMED' || 'CONNECTED' => CareAccessStatus.connected,
      'EXPIRED' => CareAccessStatus.expired,
      'REVOKED' => CareAccessStatus.revoked,
      _ => CareAccessStatus.idle,
    };
  }

  String get apiValue {
    return switch (this) {
      CareAccessStatus.active => 'ACTIVE',
      CareAccessStatus.connected => 'CLAIMED',
      CareAccessStatus.expired => 'EXPIRED',
      CareAccessStatus.revoked => 'REVOKED',
      CareAccessStatus.revoking => 'REVOKING',
      CareAccessStatus.generating => 'GENERATING',
      CareAccessStatus.syncing => 'SYNCING',
      CareAccessStatus.failure => 'FAILURE',
      CareAccessStatus.idle => 'IDLE',
    };
  }
}
