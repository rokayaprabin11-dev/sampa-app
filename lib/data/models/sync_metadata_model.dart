class SyncMetadataModel {
  final String tableName;
  final DateTime? lastFullSync;
  final DateTime? lastDeltaSync;
  final String syncStatus;

  SyncMetadataModel({
    required this.tableName,
    this.lastFullSync,
    this.lastDeltaSync,
    this.syncStatus = 'idle',
  });

  factory SyncMetadataModel.fromMap(Map<String, dynamic> map) {
    return SyncMetadataModel(
      tableName: map['table_name'],
      lastFullSync: map['last_full_sync'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_full_sync']) 
          : null,
      lastDeltaSync: map['last_delta_sync'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_delta_sync']) 
          : null,
      syncStatus: map['sync_status'] ?? 'idle',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'table_name': tableName,
      'last_full_sync': lastFullSync?.millisecondsSinceEpoch,
      'last_delta_sync': lastDeltaSync?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }
}







