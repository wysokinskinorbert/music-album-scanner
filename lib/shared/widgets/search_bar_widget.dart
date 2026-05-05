import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/search_suggestions_service.dart';

/// Search bar with recent search suggestions dropdown.
class SearchBarWithSuggestions extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback? onClear;
  final String? hint;

  const SearchBarWithSuggestions({
    super.key,
    required this.onSearch,
    this.onClear,
    this.hint,
  });

  @override
  State<SearchBarWithSuggestions> createState() =>
      _SearchBarWithSuggestionsState();
}

class _SearchBarWithSuggestionsState extends State<SearchBarWithSuggestions> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _suggestionsService = SearchSuggestionsService();
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _loadSuggestions();
        setState(() => _showSuggestions = true);
      } else {
        setState(() => _showSuggestions = false);
      }
    });
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final suggestions = await _suggestionsService.getSuggestions(
      _controller.text,
    );
    if (mounted) {
      setState(() => _suggestions = suggestions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hint ?? 'Search albums...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        _controller.clear();
                        widget.onClear?.call();
                        _loadSuggestions();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => _loadSuggestions(),
            onSubmitted: (query) {
              if (query.isNotEmpty) {
                _suggestionsService.addSearch(query);
                widget.onSearch(query);
                _focusNode.unfocus();
              }
            },
          ),
        ),

        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Recent',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await _suggestionsService.clearHistory();
                          _loadSuggestions();
                        },
                        child: const Text('Clear', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                // Suggestions list
                ..._suggestions.map((suggestion) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, color: AppColors.textTertiary, size: 16),
                    title: Text(
                      suggestion,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.north_west, color: AppColors.textTertiary, size: 14),
                      onPressed: () {
                        _controller.text = suggestion;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: suggestion.length),
                        );
                        _loadSuggestions();
                      },
                    ),
                    onTap: () {
                      _controller.text = suggestion;
                      _suggestionsService.addSearch(suggestion);
                      widget.onSearch(suggestion);
                      _focusNode.unfocus();
                    },
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}
