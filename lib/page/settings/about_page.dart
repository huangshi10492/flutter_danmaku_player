import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _showLicenses(BuildContext context, PackageInfo packageInfo) {
    final version = _formatVersion(packageInfo);
    showLicensePage(
      context: context,
      applicationName: _appName(packageInfo),
      applicationVersion: version,
    );
  }

  static String _appName(PackageInfo packageInfo) {
    if (packageInfo.appName.isEmpty) {
      return 'fldanplay';
    }
    return packageInfo.appName;
  }

  static String _formatVersion(PackageInfo packageInfo) {
    final version = packageInfo.version.isEmpty ? '-' : packageInfo.version;
    return version;
  }

  Widget _buildLoading() {
    return SettingsSection(
      title: '应用信息',
      children: [SettingsTile.simpleTile(title: '正在读取应用信息')],
    );
  }

  Widget _buildError(Object? error) {
    return SettingsSection(
      title: '应用信息',
      children: [
        SettingsTile.simpleTile(title: '应用信息读取失败', subtitle: error?.toString()),
      ],
    );
  }

  Widget _buildContent(BuildContext context, PackageInfo packageInfo) {
    final version = _formatVersion(packageInfo);

    return Column(
      children: [
        SettingsSection(
          title: '应用信息',
          children: [
            SettingsTile.simpleTile(title: '版本', subtitle: version),
            SettingsTile.simpleTile(title: '开发者', subtitle: 'huangshi10492'),
            SettingsTile.navigationTile(
              title: '项目仓库',
              subtitle:
                  'https://github.com/huangshi10492/flutter_danmaku_player',
              onPress: () => launchUrl(
                Uri.parse(
                  "https://github.com/huangshi10492/flutter_danmaku_player",
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: '开源',
          children: [
            SettingsTile.navigationTile(
              title: '开源许可证',
              subtitle: '查看 Flutter、插件和第三方库许可',
              onPress: () => _showLicenses(context, packageInfo),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '关于',
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _buildContent(context, snapshot.data!);
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error);
          }
          return _buildLoading();
        },
      ),
    );
  }
}
