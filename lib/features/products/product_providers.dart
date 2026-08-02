import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/product.dart';

/// The full products list (rows + location columns).
final productsProvider = FutureProvider.autoDispose<ProductsList>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/products');
  return ProductsList.fromJson((data as Map).cast<String, dynamic>());
});

/// One product's full edit payload (variants + per-location inventory).
final productDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/products/$id');
  return (data as Map).cast<String, dynamic>();
});

/// Dropdown data for forms (categories, fabrics, techniques, locations…).
final lookupsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/products/lookups');
  return (data as Map).cast<String, dynamic>();
});

/// Product write operations.
final productRepositoryProvider = Provider((ref) => ProductRepository(ref));

class ProductRepository {
  ProductRepository(this.ref);
  final Ref ref;

  /// Create a product. Returns the new product's id.
  Future<String> create(Map<String, dynamic> input) async {
    final data = await ref.read(apiClientProvider).post('/products', body: input);
    return ((data as Map)['id'] ?? '') as String;
  }

  Future<void> update(String id, Map<String, dynamic> input) async {
    await ref.read(apiClientProvider).patch('/products/$id', body: input);
  }

  Future<void> delete(String id) async {
    await ref.read(apiClientProvider).delete('/products/$id');
  }
}
