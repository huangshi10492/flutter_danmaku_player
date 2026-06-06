import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class RadioSettingsSection extends StatelessWidget {
  const RadioSettingsSection({
    super.key,
    this.title,
    required this.options,
    required this.value,
    required this.onChange,
    this.showOnlySubtitle = false,
  });
  final String? title;
  final Map<String, String> options;
  final String value;
  final void Function(String) onChange;
  final bool showOnlySubtitle;

  static const double minHeight = 40;
  TextStyle subtitleStyle(BuildContext context) =>
      context.theme.tileStyles.base.contentStyle.subtitleTextStyle.base;

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
              title: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: showOnlySubtitle
                      ? [Text(e.value)]
                      : [
                          Text(e.key),
                          SizedBox(height: 2),
                          Text(e.value, style: subtitleStyle(context)),
                        ],
                ),
              ),
              value: e.key,
            ),
          )
          .toList(),
    );
  }
}
