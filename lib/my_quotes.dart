import 'package:flutter/material.dart';

import 'quotes.dart';

/// Lets the user add, edit and remove their own quotes. Every change is passed
/// to [onChanged] straight away, so the widget is kept up to date.
class MyQuotesPage extends StatefulWidget {
  const MyQuotesPage({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final MyQuotes initial;
  final ValueChanged<MyQuotes> onChanged;

  @override
  State<MyQuotesPage> createState() => _MyQuotesPageState();
}

class _MyQuotesPageState extends State<MyQuotesPage> {
  late MyQuotes _mine = widget.initial;

  void _update(MyQuotes mine) {
    setState(() => _mine = mine);
    widget.onChanged(mine);
  }

  Future<void> _edit([int? index]) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) =>
          _QuoteDialog(initial: index == null ? null : _mine.quotes[index]),
    );
    if (text == null) return;
    final quotes = [..._mine.quotes];
    if (index == null) {
      quotes.add(text);
    } else {
      quotes[index] = text;
    }
    _update(_mine.copyWith(quotes: quotes));
  }

  void _remove(int index) {
    final removed = _mine.quotes[index];
    _update(_mine.copyWith(quotes: [..._mine.quotes]..removeAt(index)));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Quote removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _update(
              _mine.copyWith(
                quotes: [..._mine.quotes]
                  ..insert(index.clamp(0, _mine.quotes.length), removed),
              ),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final quotes = _mine.quotes;
    return Scaffold(
      appBar: AppBar(title: const Text('My quotes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Add quote'),
      ),
      body: ListView(
        // Extra bottom space so the last quote clears the button.
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show only my quotes'),
            subtitle: Text(
              quotes.isEmpty
                  ? 'Add a quote first'
                  : _mine.onlyMine
                  ? 'The built-in quotes are hidden'
                  : 'Mixed in with ${builtInQuotes.length} built-in quotes',
            ),
            value: _mine.onlyMine && quotes.isNotEmpty,
            onChanged: quotes.isEmpty
                ? null
                : (on) => _update(_mine.copyWith(onlyMine: on)),
          ),
          const Divider(),
          if (quotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Add your own lines: a Bible verse, something your mum always '
                'says, or a goal you want to keep in mind.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (var i = 0; i < quotes.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_quote),
              title: Text(quotes[i]),
              onTap: () => _edit(i),
              trailing: IconButton(
                tooltip: 'Remove quote',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _remove(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuoteDialog extends StatefulWidget {
  const _QuoteDialog({this.initial});

  final String? initial;

  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<_QuoteDialog> {
  late final _text = TextEditingController(text: widget.initial ?? '');

  String get _quote => _text.text.trim();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add quote' : 'Edit quote'),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: maxQuoteLength,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Small small, you go reach where you dey go.',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _quote.isEmpty
              ? null
              : () => Navigator.of(context).pop(_quote),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
