import 'dart:convert';

/// The signed-in till session — who is operating and at which store. Mirrors the
/// API's session shape (staffId, name, role, storeId, storeName, storeCode).
class Session {
  const Session({
    required this.staffId,
    required this.name,
    required this.role,
    required this.storeId,
    required this.storeName,
    required this.storeCode,
  });

  final String staffId;
  final String name;
  final String role; // 'owner' | 'cashier'
  final String storeId;
  final String storeName;
  final String storeCode;

  bool get isOwner => role == 'owner';

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        staffId: (j['staffId'] ?? j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        role: (j['role'] ?? 'cashier') as String,
        storeId: (j['storeId'] ?? j['store'] ?? '') as String,
        storeName: (j['storeName'] ?? '') as String,
        storeCode: (j['storeCode'] ?? 'R1') as String,
      );

  Map<String, dynamic> toJson() => {
        'staffId': staffId,
        'name': name,
        'role': role,
        'storeId': storeId,
        'storeName': storeName,
        'storeCode': storeCode,
      };

  String encode() => jsonEncode(toJson());
  static Session decode(String s) => Session.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
