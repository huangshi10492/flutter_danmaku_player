// .icon-jellyfin:before { content: "\e900"; }
// .icon-emby:before { content: "\e901"; }
// .icon-bilibili:before { content: "\e902"; }
// .icon-ftp:before { content: "\e903"; }
// .icon-smb:before { content: "\e904"; }
// .icon-bahamut:before { content: "\e905"; }
// .icon-dandanplay:before { content: "\e906"; }
// .icon-danmaku:before { content: "\e907"; }
// .icon-danmaku-off:before { content: "\e908"; }
// .icon-danmaku-settings:before { content: "\e909"; }

import 'package:material_ui/material_ui.dart';

class MyIcon {
  static const String _family = 'IconFont';
  const MyIcon._();
  static const IconData jellyfin = IconData(0xe900, fontFamily: _family);
  static const IconData emby = IconData(0xe901, fontFamily: _family);
  static const IconData bilibili = IconData(0xe902, fontFamily: _family);
  static const IconData ftp = IconData(0xe903, fontFamily: _family);
  static const IconData smb = IconData(0xe904, fontFamily: _family);
  static const IconData bahamut = IconData(0xe905, fontFamily: _family);
  static const IconData dandanplay = IconData(0xe906, fontFamily: _family);
  static const IconData danmaku = IconData(0xe907, fontFamily: _family);
  static const IconData danmakuOff = IconData(0xe908, fontFamily: _family);
  static const IconData danmakuSettings = IconData(0xe909, fontFamily: _family);
}
