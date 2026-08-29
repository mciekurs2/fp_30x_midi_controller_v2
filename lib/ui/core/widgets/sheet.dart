import 'package:flutter/material.dart';

/// The gap every sheet lays its rows out on.
const sheetSpacing = 8.0;

/// Opens [sheet] as a bottom sheet.
///
/// `isScrollControlled` so a tall one — chords-in-key stacks a key picker on
/// the time and octave knobs — can pass the default half-height instead of
/// overflowing; [SheetBody] scrolls whatever is still too tall for the screen.
Future<void> showAppSheet(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => sheet,
    );

/// The body every bottom sheet shares: a stretched column, inset and safe-area
/// padded, that scrolls rather than overflowing. Its content is only as tall as
/// it needs to be, so a short sheet still hugs the bottom of the screen.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const .fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: sheetSpacing,
        children: children,
      ),
    ),
  );
}

/// A section title, with the current value trailing it.
///
/// [value] is for a setting whose choice is not legible from its own control —
/// the time limit's slider, which names its position only while it is being
/// dragged. Where the control already shows what is chosen, as a chip row or a
/// radio list does, the trailing value only says it twice.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const Spacer(),
        if (value case final value?)
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// A chip label that fills and centres, so chips in an [Expanded] row read as
/// equal-width buttons rather than left-aligned text.
class ChipLabel extends StatelessWidget {
  const ChipLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: double.infinity, child: Text(text, textAlign: .center));
}

/// A row of equal-width chips, one per item.
class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.items,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.multiple = false,
  });

  final Iterable<T> items;
  final String Function(T item) label;
  final bool Function(T item) isSelected;
  final void Function(T item, bool selected) onSelected;

  /// Several may be on at once — a [FilterChip] rather than a [ChoiceChip].
  final bool multiple;

  @override
  Widget build(BuildContext context) => Row(
    spacing: sheetSpacing,
    children: [
      for (final item in items)
        Expanded(
          child: multiple
              ? FilterChip(
                  label: ChipLabel(label(item)),
                  showCheckmark: false,
                  selected: isSelected(item),
                  onSelected: (selected) => onSelected(item, selected),
                )
              : ChoiceChip(
                  label: ChipLabel(label(item)),
                  showCheckmark: false,
                  selected: isSelected(item),
                  onSelected: (_) => onSelected(item, true),
                ),
        ),
    ],
  );
}
