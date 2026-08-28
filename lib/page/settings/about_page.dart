import 'package:fldanplay/model/update.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/directional_scroll_view.dart';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final gs = GetIt.I.get<GlobalService>();
  final cs = GetIt.I.get<ConfigureService>();
  bool _loading = false;

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: gs.packageInfo.appName,
      applicationVersion: gs.packageInfo.version,
    );
  }

  Widget? _buildVersionSuffix() {
    if (_loading) {
      return FCircularProgress(size: .lg);
    }
    if (gs.updateInfo.value == null) return null;
    if (!gs.updateInfo.value!.hasUpdate) return Text('已是最新版本');
    return FBadge(
      child: Row(
        children: [
          SizedBox(width: 4),
          Text(gs.updateInfo.value!.latestVersion),
          SizedBox(width: 2),
          Icon(
            FLucideIcons.arrowUp,
            size: 16,
            color: context.theme.colors.primaryForeground,
          ),
        ],
      ),
    );
  }

  void _versionPress() async {
    if (_loading) return;
    if (gs.updateInfo.value != null) {
      if (gs.updateInfo.value!.hasUpdate) {
        context.push('/settings/about/update');
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final res = await gs.checkUpdate();
      if (res) showToast(title: '检测到新版本', description: gs.packageInfo.version);
    } catch (e) {
      showToast(level: 3, title: '获取更新失败', description: e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '关于',
      child: Column(
        children: [
          SettingsSection(
            title: '应用信息',
            children: [
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
              SettingsTile.navigationTile(
                title: '开源许可证',
                subtitle: '查看 Flutter、插件和第三方库许可',
                onPress: () => _showLicenses(context),
              ),
            ],
          ),
          SettingsSection(
            title: '版本',
            children: [
              SettingsTile.simpleTile(
                title: '当前版本',
                subtitle: gs.packageInfo.version,
                suffix: _buildVersionSuffix(),
                onPress: _versionPress,
              ),
              SignalBuilder(
                builder: (context) => SettingsTile.switchTile(
                  title: '自动检查更新',
                  subtitle: '应用启动时自动检查更新',
                  switchValue: cs.checkUpdate.value,
                  onBoolChange: (v) => cs.checkUpdate.value = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UpdateInfoPage extends StatefulWidget {
  const UpdateInfoPage({super.key});

  @override
  State<UpdateInfoPage> createState() => _UpdateInfoPageState();
}

class _UpdateInfoPageState extends State<UpdateInfoPage> {
  final updateInfo = GetIt.I.get<GlobalService>().updateInfo.value!;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final dateFormat = DateFormat('yyyy-MM-dd');
  FCardStyle get style => context.theme.cardStyle;
  MarkdownStyleSheet get markdownStyleSheet => MarkdownStyleSheet(
    p: context.theme.typography.body.xs,
    h1: context.theme.typography.body.lg,
    h2: context.theme.typography.body.md,
    h3: context.theme.typography.body.sm,
    listBullet: context.theme.typography.body.xs,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _launchUrl(String url) {
    final Uri uri = Uri.parse(url);
    launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final releases = updateInfo.releases;
    return SettingsScaffold(
      title: '更新日志',
      scrollView: false,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) =>
            handleKeyEvent(node, event, _scrollController),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const .symmetric(vertical: 8),
                itemCount: releases.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, index) => _buildCard(
                  releases[index],
                  dateFormat.format(
                    DateTime.parse(releases[index].publishedAt).toLocal(),
                  ),
                ),
              ),
            ),
            FButton(
              autofocus: true,
              onPress: () => _launchUrl(
                'https://github.com/huangshi10492/flutter_danmaku_player/releases',
              ),
              child: const Text('前往更新'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Release release, String formattedDate) {
    return FCard(
      child: Padding(
        padding: style.padding,
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(release.version, style: context.theme.typography.body.xl),
                Text(formattedDate, style: style.subtitleTextStyle),
              ],
            ),
            const FDivider(),
            MarkdownBody(
              data: release.changelog,
              styleSheet: markdownStyleSheet,
              onTapLink: (text, href, title) {
                if (href != null) _launchUrl(href);
              },
            ),
          ],
        ),
      ),
    );
  }
}
