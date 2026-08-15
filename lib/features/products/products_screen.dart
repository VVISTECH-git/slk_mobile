import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker_field.dart';
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

  final List<PieceListRow> _rows = [];
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
      final res = await ref.read(productRepositoryProvider).pagePieces(
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
          await context.push('/tag');
          _reset();
        },
        backgroundColor: context.p.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_2),
        label: const Text('Tag pieces'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search QR, design or colour',
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
                child: Text('${_rows.length} of $_total pieces',
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
    if (_rows.isEmpty) return const Center(child: Text('No pieces match your search.'));
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
          return _PieceCard(row: _rows[i]);
        },
      ),
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({required this.row});
  final PieceListRow row;

  @override
  Widget build(BuildContext context) {
    final colour = row.colour;
    final meta = <String>[
      if (colour != null && colour.isNotEmpty) colour,
      if (row.size != null && row.size!.isNotEmpty) row.size!,
    ].join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/piece/${Uri.encodeComponent(row.tagCode)}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_2, size: 18, color: context.p.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(row.tagCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3)),
                  ),
                  _StatusChip(status: row.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(row.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (colour != null && colour.isNotEmpty) ...[
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colourSwatch(colour),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.p.border),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(meta.isEmpty ? row.productCode : meta,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  ),
                  if (row.location != null && row.location!.isNotEmpty) ...[
                    Icon(Icons.place_outlined, size: 14, color: context.p.textSecondary),
                    const SizedBox(width: 3),
                    Text(row.location!,
                        style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  String get _label {
    switch (status) {
      case 'in_transit':
        return 'In transit';
      case 'available':
        return 'Available';
      default:
        return status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = status == 'available'
        ? context.p.success
        : status == 'in_transit'
            ? context.p.accent
            : status == 'sold'
                ? context.p.textSecondary
                : context.p.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(_label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
