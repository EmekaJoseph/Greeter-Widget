import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'widget_store.dart';

/// Width of the shared image in pixels; 4:5 suits WhatsApp, Instagram and chats.
const double shareImageWidth = 1080;
const double shareCardAspectRatio = 4 / 5;

/// Shows a preview of [quote] as a card in the user's theme, and shares it as
/// an image when they confirm.
Future<void> showShareQuoteSheet(
  BuildContext context, {
  required String quote,
  required WidgetAppearance look,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ShareQuoteSheet(quote: quote, look: look),
  );
}

class _ShareQuoteSheet extends StatefulWidget {
  const _ShareQuoteSheet({required this.quote, required this.look});

  final String quote;
  final WidgetAppearance look;

  @override
  State<_ShareQuoteSheet> createState() => _ShareQuoteSheetState();
}

class _ShareQuoteSheetState extends State<_ShareQuoteSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: shareImageWidth / boundary.size.width,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/greeter_quote.png');
      await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '"${widget.quote}"',
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not share the quote: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ShareQuoteCard(quote: widget.quote, look: widget.look),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: const Text('Share image'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The image that gets shared. Sized by its width, so it renders the same in
/// the preview and in the exported picture.
class ShareQuoteCard extends StatelessWidget {
  const ShareQuoteCard({super.key, required this.quote, required this.look});

  final String quote;
  final WidgetAppearance look;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: shareCardAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Everything scales with the card, so the exported image matches the preview.
          final unit = constraints.maxWidth / 100;
          return Container(
            color: look.cardColor,
            padding: EdgeInsets.all(unit * 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“',
                  style: TextStyle(
                    color: look.accentColor,
                    fontSize: unit * 30,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: constraints.maxWidth - unit * 18,
                        child: Text(
                          quote,
                          style: TextStyle(
                            color: look.textColor,
                            fontSize: unit * 8.5,
                            height: 1.3,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Balances the opening quote mark so the quote sits centred.
                SizedBox(height: unit * 15),
              ],
            ),
          );
        },
      ),
    );
  }
}
