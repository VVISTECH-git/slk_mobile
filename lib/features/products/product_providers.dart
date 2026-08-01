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
final lookupsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/products/lookups');
  return (data as Map).cast<String, dynamic>();
});
