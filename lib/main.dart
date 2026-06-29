import 'dart:io';

import 'package:catcher_2/catcher_2.dart';
import 'package:catcher_2/model/platform_type.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:fldanplay/hive/hive_registrar.g.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/service_locator.dart';
import 'package:fldanplay/utils/shader.dart';
import 'package:fldanplay/utils/theme.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/scale_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  ScaledWidgetsFlutterBinding.ensureInitialized();
  await init();
  upgrade();
  final Catcher2Options config = Catcher2Options(SilentReportMode(), [
    CatcherLogger(),
  ]);

  Catcher2(
    debugConfig: config,
    releaseConfig: config,
    enableLogger: false,
    runAppFunction: () {
      runApp(const Application());
    },
  );
}

Future<void> init() async {
  if (Utils.isDesktop()) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: const Size(1440, 810),
      center: true,
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  SignalsObserver.instance = null;
  await Hive.initFlutter(
    '${(await getApplicationSupportDirectory()).path}/hive',
  );
  Hive.registerAdapters();
  final cs = await ServiceLocator.initialize();
  ScaledWidgetsFlutterBinding.instance.scaleFactor = cs.uiScale.value;
  MediaKit.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
    );
  }
  SuperResolutionUtils.initFile();
}

void upgrade() {
  final cs = GetIt.I.get<ConfigureService>();
  List<String> list = cs.danmakuServerList.value;
  for (var i = 0; i < list.length; i++) {
    if (list[i] == 'https://danmaku.huangshi10492.top/huangshi10492') {
      list[i] = 'https://api.dandanplay.net';
    }
  }
  cs.danmakuServerList.value = list;
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> with WidgetsBindingObserver {
  _ApplicationState();

  final _isDark = signal(
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _isDark.value =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final configureService = GetIt.I.get<ConfigureService>();
        final themeMode = configureService.themeMode.value;
        final themeColor = configureService.themeColor.value;
        var materialThemeMode = ThemeMode.system;
        switch (themeMode) {
          case '0':
            materialThemeMode = ThemeMode.system;
            break;
          case '1':
            materialThemeMode = ThemeMode.light;
            break;
          case '2':
            materialThemeMode = ThemeMode.dark;
            break;
        }
        late FThemeData fTheme;
        switch (themeMode) {
          case '0':
            fTheme = getTheme(themeColor, _isDark.value);
            break;
          case '1':
            fTheme = getTheme(themeColor, false);
            break;
          case '2':
            fTheme = getTheme(themeColor, true);
            break;
        }
        return MaterialApp.router(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
              countryCode: "CN",
            ),
          ],
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: "CN",
          ),
          theme: getTheme(themeColor, false).toApproximateMaterialTheme(),
          darkTheme: getTheme(themeColor, true).toApproximateMaterialTheme(),
          themeMode: materialThemeMode,
          builder: (context, child) => FTheme(
            data: fTheme,
            child: FToaster(
              child: _builder(
                context,
                Builder(
                  builder: (context) {
                    GetIt.I.get<GlobalService>().appContext = context;
                    return child!;
                  },
                ),
              ),
            ),
          ),
          routerConfig: router,
        );
      },
    );
  }

  static Widget _builder(BuildContext context, Widget child) {
    final uiScale = GetIt.I.get<ConfigureService>().uiScale.value;
    if (uiScale != 1.0) {
      final mediaQuery = MediaQuery.of(context);
      child = MediaQuery(
        data: mediaQuery.copyWith(
          size: mediaQuery.size / uiScale,
          padding: (mediaQuery.padding) / uiScale,
          viewInsets: mediaQuery.viewInsets / uiScale,
          viewPadding: (mediaQuery.viewPadding) / uiScale,
          devicePixelRatio: mediaQuery.devicePixelRatio * uiScale,
        ),
        child: child,
      );
    }
    return child;
  }
}

class CatcherLogger extends ConsoleHandler {
  final loggerService = Logger('Catcher');

  @override
  Future<bool> handle(Report report, BuildContext? context) async {
    loggerService.error(
      'crash',
      report.error.toString(),
      error: report.error,
      stackTrace: report.stackTrace,
    );
    return true;
  }

  @override
  List<PlatformType> getSupportedPlatforms() => PlatformType.values;
}
