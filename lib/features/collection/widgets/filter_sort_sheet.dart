import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/collection/collection_sort_service.dart';
import '../../../data/services/collection/collection_filter_service.dart';

/// Bottom sheet for filtering and sorting collection.
class FilterSortSheet extends StatefulWidget {
  final SortConfig currentSort;
  final CollectionFilter currentFilter;
  final List<String> availableGenres;
  final List<int> availableDecades;
  final List<String> availableLabels;

  const FilterSortSheet({
    super.key,
    required this.currentSort,
    required this.currentFilter,
    this.availableGenres = const [],
    this.availableDecades = const [],
    this.availableLabels = const [],
  });

  @override
  State<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<FilterSortSheet> {
  late SortConfig _sort;
  late CollectionFilter _filter;

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _filter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Filter & Sort', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: _resetAll,
                  child: const Text('Reset', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort section
                  _sectionTitle('Sort by'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SortField.values.map((field) {
                      return ChoiceChip(
                        label: Text(field.name),
                        selected: _sort.field == field,
                        onSelected: (_) => setState(() => _sort = _sort.copyWith(field: field)),
                        selectedColor: AppColors.primary.withOpacity(0.2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Sort order
                  Row(
                    children: [
                      const Text('Order:', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Ascending'),
                        selected: _sort.order == SortOrder.ascending,
                        onSelected: (_) => setState(() => _sort = _sort.copyWith(order: SortOrder.ascending)),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Descending'),
                        selected: _sort.order == SortOrder.descending,
                        onSelected: (_) => setState(() => _sort = _sort.copyWith(order: SortOrder.descending)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Genre filter
                  if (widget.availableGenres.isNotEmpty) ...[
                    _sectionTitle('Genre'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.availableGenres.map((genre) {
                        return ChoiceChip(
                          label: Text(genre),
                          selected: _filter.genre == genre,
                          onSelected: (_) => setState(() {
                            _filter = _filter.genre == genre
                                ? _filter.copyWith(clearGenre: true)
                                : _filter.copyWith(genre: genre);
                          }),
                          selectedColor: Colors.green.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Decade filter
                  if (widget.availableDecades.isNotEmpty) ...[
                    _sectionTitle('Decade'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.availableDecades.map((decade) {
                        return ChoiceChip(
                          label: Text('\${decade}s'),
                          selected: _filter.decade == decade,
                          onSelected: (_) => setState(() {
                            _filter = _filter.decade == decade
                                ? _filter.copyWith(clearDecade: true)
                                : _filter.copyWith(decade: decade);
                          }),
                          selectedColor: Colors.orange.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Min confidence
                  _sectionTitle('Min Confidence'),
                  Slider(
                    value: _filter.minConfidence ?? 0,
                    min: 0,
                    max: 1.0,
                    divisions: 10,
                    label: _filter.minConfidence != null
                        ? '${(_filter.minConfidence! * 100).toStringAsFixed(0)}%'
                        : 'Any',
                    onChanged: (v) => setState(() {
                      _filter = v == 0
                          ? _filter.copyWith(clearConfidence: true)
                          : _filter.copyWith(minConfidence: v);
                    }),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  void _resetAll() {
    setState(() {
      _sort = const SortConfig();
      _filter = const CollectionFilter();
    });
  }

  void _apply() {
    Navigator.pop(context, (_sort, _filter));
  }
}
