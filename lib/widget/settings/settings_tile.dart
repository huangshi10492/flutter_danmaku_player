import 'package:fldanplay/theme/tile_style.dart';
import 'package:forui/forui.dart';
import 'package:flutter/material.dart';

enum SettingsTileType {
  simpleTile,
  switchTile,
  sliderTile,
  navigationTile,
  radioTile,
}

class SettingsTile extends StatelessWidget with FTileMixin {
  SettingsTile.simpleTile({
    super.key,
    required this.title,
    this.subtitle,
    this.details,
    this.suffix,
    this.onPress,
  }) {
    onBoolChange = null;
    onSilderChange = null;
    onRadioChange = null;
    radioOptions = null;
    switchValue = null;
    silderValue = null;
    silderDivisions = null;
    silderMin = null;
    silderMax = null;
    radioValue = null;
    type = SettingsTileType.simpleTile;
  }
  SettingsTile.switchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.details,
    this.suffix,
    required this.onBoolChange,
    required this.switchValue,
  }) {
    onPress = () => onBoolChange!(!switchValue!);
    onSilderChange = null;
    onRadioChange = null;
    radioOptions = null;
    silderValue = null;
    silderDivisions = null;
    silderMin = null;
    silderMax = null;
    radioValue = null;
    type = SettingsTileType.switchTile;
  }
  SettingsTile.sliderTile({
    super.key,
    required this.title,
    this.details,
    this.subtitle,
    this.suffix,
    required this.onSilderChange,
    required this.silderValue,
    required this.silderDivisions,
    required this.silderMin,
    required this.silderMax,
  }) {
    onPress = null;
    onBoolChange = null;
    onRadioChange = null;
    radioOptions = null;
    switchValue = null;
    radioValue = null;
    type = SettingsTileType.sliderTile;
  }
  SettingsTile.navigationTile({
    super.key,
    required this.title,
    this.subtitle,
    this.details,
    this.onPress,
  }) {
    suffix = const Icon(FIcons.chevronRight);
    onBoolChange = null;
    onSilderChange = null;
    onRadioChange = null;
    radioOptions = null;
    switchValue = null;
    silderValue = null;
    silderDivisions = null;
    silderMin = null;
    silderMax = null;
    radioValue = null;
    type = SettingsTileType.navigationTile;
  }
  SettingsTile.radioTile({
    super.key,
    required this.title,
    this.subtitle,
    this.suffix,
    required this.onRadioChange,
    required this.radioOptions,
    required this.radioValue,
  }) {
    details = null;
    onPress = null;
    onBoolChange = null;
    onSilderChange = null;
    switchValue = null;
    silderValue = null;
    silderDivisions = null;
    silderMin = null;
    silderMax = null;
    type = SettingsTileType.radioTile;
  }

  final String title;
  late final String? details;
  late final String? subtitle;
  late final VoidCallback? onPress;
  late final SettingsTileType type;
  late final Widget? suffix;
  late final void Function(bool)? onBoolChange;
  late final void Function(double)? onSilderChange;
  late final void Function(String)? onRadioChange;
  late final Map<String, String>? radioOptions;
  late final bool? switchValue;
  late final double? silderValue;
  late final int? silderDivisions;
  late final double? silderMin;
  late final double? silderMax;
  late final String? radioValue;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case SettingsTileType.simpleTile:
        return _buildSimpleTile(context);
      case SettingsTileType.switchTile:
        return _buildSwitchTile(context);
      case SettingsTileType.sliderTile:
        return _buildSliderTile(context);
      case SettingsTileType.navigationTile:
        return _buildSimpleTile(context);
      case SettingsTileType.radioTile:
        return _buildRadioTile(context);
    }
  }

  TextStyle subtitleStyle(BuildContext context) =>
      context.theme.itemStyles.base.contentStyle.subtitleTextStyle.base;

  Widget _buildSimpleTile(BuildContext context) {
    return FTile(
      style: tileStyle(
        colors: context.theme.colors,
        typography: context.theme.typography,
        style: context.theme.style,
      ),
      title: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, maxLines: 2),
            subtitle == null
                ? SizedBox()
                : Text(
                    subtitle!,
                    style: subtitleStyle(context),
                    overflow: TextOverflow.visible,
                  ),
          ],
        ),
      ),
      details: details == null ? null : Text(details!),
      suffix: suffix,
      onPress: onPress,
    );
  }

  Widget _buildSwitchTile(BuildContext context) {
    return FTile(
      style: tileStyle(
        colors: context.theme.colors,
        typography: context.theme.typography,
        style: context.theme.style,
      ),
      title: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
            subtitle == null
                ? SizedBox()
                : Text(
                    subtitle!,
                    style: subtitleStyle(context),
                    overflow: TextOverflow.visible,
                  ),
          ],
        ),
      ),
      onPress: onPress,
      suffix: SizedBox(
        height: 40,
        child: Switch(
          value: switchValue!,
          onChanged: (value) => onBoolChange!(value),
        ),
      ),
    );
  }

  Widget _buildSliderTile(BuildContext context) {
    return FTile(
      style: tileStyle(
        colors: context.theme.colors,
        typography: context.theme.typography,
        style: context.theme.style,
      ),
      title: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(title), Text(details ?? '')],
            ),
            Slider(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              value: silderValue!,
              min: silderMin!,
              max: silderMax!,
              divisions: silderDivisions,
              onChanged: (value) => onSilderChange!(value),
            ),
            subtitle == null || subtitle == ''
                ? SizedBox()
                : Text(
                    subtitle!,
                    style: subtitleStyle(context),
                    overflow: TextOverflow.visible,
                  ),
          ],
        ),
      ),
      suffix: suffix,
      onPress: onPress,
    );
  }

  Widget _buildRadioTile(BuildContext context) {
    return FSelectMenuTile.fromMap(
      selectControl: .lifted(
        value: {radioValue},
        onChange: (value) => onRadioChange!(value.last!),
      ),
      radioOptions!,
      style: .delta(
        tileStyle: .delta(
          backgroundColor: FVariants.all(Colors.transparent),
          decoration: .delta([
            .all(.delta(border: null)),
            .base(.delta(color: Colors.transparent)),
          ]),
        ),
      ),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, overflow: TextOverflow.visible),
      details: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              radioOptions!.entries
                  .firstWhere((e) => e.value == radioValue)
                  .key,
            ),
          ],
        ),
      ),
      suffix: suffix,
    );
  }
}
