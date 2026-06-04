import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class RadioSettingsSection extends StatelessWidget {
  const RadioSettingsSection({
    super.key,
    this.title,
    required this.options,
    required this.value,
    required this.onChange,
  });
  final String? title;
  final Map<String, String> options;
  final String value;
  final void Function(String) onChange;

  @override
  Widget build(BuildContext context) {
    return FSelectTileGroup<String>(
      control: .managed(
        controller: FMultiValueNotifier.radio(value),
        onChange: (value) => onChange(value.first),
      ),
      style: .delta(
        decoration: .boxDelta(
          color: context.theme.colors.secondary.withAlpha(100),
        ),
        tileStyles: .delta([
          .all(
            .delta(
              contentDecoration: .delta([
                .base(.boxDelta(color: Colors.transparent)),
              ]),
              backgroundColor: .delta([.all(Colors.transparent)]),
              contentStyle: .delta(
                suffixedPadding: .value(
                  .symmetric(horizontal: 15, vertical: 8),
                ),
                unsuffixedPadding: .value(
                  .symmetric(horizontal: 15, vertical: 8),
                ),
              ),
            ),
          ),
        ]),
      ),
      children: options.entries
          .map(
            (e) => FSelectTile(
              title: Text(e.key),
              subtitle: Text(e.value),
              value: e.key,
            ),
          )
          .toList(),
    );
  }
}
