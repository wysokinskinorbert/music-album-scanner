import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/collection/wishlist_service.dart';

/// Wishlist screen - albums to find.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _service = WishlistService();
  List<WishlistItem> _items = [];
  bool _isLoading = true;
  bool _showFound = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = _showFound ? await _service.getAll() : await _service.getUnfound();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          IconButton(
            icon: Icon(_showFound ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() => _showFound = !_showFound);
              _loadItems();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addManual,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _items.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 64, color: AppColors.textTertiary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Your wishlist is empty',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add albums you want to find',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addManual,
            icon: const Icon(Icons.add),
            label: const Text('Add Album'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadItems,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16).copyWith(bottom: 80),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _WishlistItemCard(
            item: item,
            onMarkFound: () => _markFound(item),
            onDelete: () => _deleteItem(item),
          );
        },
      ),
    );
  }

  Future<void> _addManual() async {
    final title = TextEditingController();
    final artist = TextEditingController();
    final notes = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add to Wishlist', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Album Title',
                labelStyle: TextStyle(color: AppColors.textTertiary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: artist,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Artist',
                labelStyle: TextStyle(color: AppColors.textTertiary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notes,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: TextStyle(color: AppColors.textTertiary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _service.createManual(
        title: title.text.isEmpty ? null : title.text,
        artist: artist.text.isEmpty ? null : artist.text,
        notes: notes.text.isEmpty ? null : notes.text,
      );
      _loadItems();
    }
  }

  Future<void> _markFound(WishlistItem item) async {
    if (item.id != null) {
      await _service.markFound(item.id!);
      _loadItems();
    }
  }

  Future<void> _deleteItem(WishlistItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove from wishlist?'),
        content: Text('${item.title ?? "This album"} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && item.id != null) {
      await _service.remove(item.id!);
      _loadItems();
    }
  }
}

class _WishlistItemCard extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onMarkFound;
  final VoidCallback onDelete;

  const _WishlistItemCard({
    required this.item,
    required this.onMarkFound,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id ?? item.dateAdded.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: item.isFound
              ? Border.all(color: Colors.green.withOpacity(0.3))
              : Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.isFound ? Colors.green.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.isFound ? Icons.check_circle : Icons.album,
                color: item.isFound ? Colors.green : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title ?? 'Unknown Album',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: item.isFound ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.artist != null)
                    Text(
                      item.artist!,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      maxLines: 1,
                    ),
                  if (item.notes != null && item.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.notes!,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // Actions
            if (!item.isFound)
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green, size: 20),
                onPressed: onMarkFound,
                tooltip: 'Mark found',
              ),
          ],
        ),
      ),
    );
  }
}
