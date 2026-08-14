import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import 'product_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  static const _pageSize = 30;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  final List<ProductListRow> _rows = [];
  int _total = 0;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reset();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _reset() async {
    setState(() {
      _rows.clear();
      _total = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(productRepositoryProvider).page(
            search: _search.text,
            limit: _pageSize,
            offset: _rows.length,
          );
      setState(() {
        _rows.addAll(res.rows);
        _total = res.total;
        _hasMore = _rows.length < res.total && res.rows.isNotEmpty;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          const ThemeButton(),
          IconButton(tooltip: 'Refresh', onPressed: _reset, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/products/new');
          _reset();
        },
        backgroundColor: context.p.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search name, code or SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _reset();
                        },
                      ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_total > 0 || _rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_rows.length} of $_total',
                    style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
              ),
            ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_error', style: TextStyle(color: context.p.danger)),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _reset, child: const Text('Try again')),
        ]),
      );
    }
    if (_rows.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) return const Center(child: Text('No products match your search.'));
    return RefreshIndicator(
      onRefresh: _reset,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i >= _rows.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ProductCard(row: _rows[i]);
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.row});
  final ProductListRow row;

  String get _price {
    if (row.minPrice == null) return 'No price';
    if (row.maxPrice == null || row.minPrice == row.maxPrice) return money0(row.minPrice!);
    return '${money0(row.minPrice!)} – ${money0(row.maxPrice!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/products/${row.productId ?? row.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(row.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  if ((row.colour ?? '').isNotEmpty) ...[
                    _ColourChip(colour: row.colour!),
                    const SizedBox(width: 8),
                  ],
                  _StatusChip(status: row.status),
                ],
              ),
              const SizedBox(height: 2),
              Text('${row.productCode}${row.categoryPath.isNotEmpty ? ' · ${row.categoryPath}' : ''}',
                  style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Pill(icon: Icons.sell_outlined, text: _price),
                  const Spacer(),
                  if (row.lowStock)
                    Icon(Icons.warning_amber_rounded, color: context.p.danger, size: 18),
                  const SizedBox(width: 4),
                  Text('${row.totalStock} in stock',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: row.lowStock ? context.p.danger : context.p.text)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColourChip extends StatelessWidget {
  const _ColourChip({required this.colour});
  final String colour;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.p.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(colour,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.p.primaryDark)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'active'
        ? context.p.success
        : status == 'draft'
            ? context.p.accent
            : context.p.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(status[0].toUpperCase() + status.substring(1),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.p.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
      ],
    );
  }
}
