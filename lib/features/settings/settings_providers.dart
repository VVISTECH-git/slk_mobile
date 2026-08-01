import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Full settings payload (owner-only): business profile, staff, categories,
/// locations, attributes.
final settingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/settings');
  return (data as Map).cast<String, dynamic>();
});

final settingsRepositoryProvider = Provider((ref) => SettingsRepository(ref));

class SettingsRepository {
  SettingsRepository(this.ref);
  final Ref ref;

  Future<void> saveBusiness(Map<String, String> profile) async {
    await ref.read(apiClientProvider).put('/settings/business', body: profile);
  }

  // ---- staff ----
  Future<void> addStaff({required String name, required String pin, String? storeId, required String role}) async {
    await ref.read(apiClientProvider).post('/settings/staff', body: {
      'name': name,
      'pin': pin,
      if (storeId != null) 'storeId': storeId,
      'role': role,
    });
  }

  Future<void> updateStaff(String id, {required String name, String? storeId, required String role, String? pin}) async {
    await ref.read(apiClientProvider).patch('/settings/staff/$id', body: {
      'name': name,
      if (storeId != null) 'storeId': storeId,
      'role': role,
      if (pin != null && pin.isNotEmpty) 'pin': pin,
    });
  }

  Future<void> deleteStaff(String id) async {
    await ref.read(apiClientProvider).delete('/settings/staff/$id');
  }

  // ---- locations ----
  Future<void> addLocation(String name, String type) async {
    await ref.read(apiClientProvider).post('/settings/locations', body: {'name': name, 'type': type});
  }

  Future<void> deleteLocation(String id) async {
    await ref.read(apiClientProvider).delete('/settings/locations/$id');
  }

  // ---- categories ----
  Future<void> addCategory(String name, String? parentId) async {
    await ref.read(apiClientProvider).post('/settings/categories', body: {
      'name': name,
      if (parentId != null) 'parentId': parentId,
    });
  }

  Future<void> updateCategory(String id, {String? name, String? code}) async {
    await ref.read(apiClientProvider).patch('/settings/categories/$id', body: {
      if (name != null) 'name': name,
      if (code != null) 'code': code,
    });
  }

  Future<void> deleteCategory(String id) async {
    await ref.read(apiClientProvider).delete('/settings/categories/$id');
  }

  // ---- attributes (fabric | technique | dye | border) ----
  Future<void> addAttribute(String kind, String name) async {
    await ref.read(apiClientProvider).post('/settings/attributes/$kind', body: {'name': name});
  }

  Future<void> deleteAttribute(String kind, String id) async {
    await ref.read(apiClientProvider).delete('/settings/attributes/$kind/$id');
  }
}
