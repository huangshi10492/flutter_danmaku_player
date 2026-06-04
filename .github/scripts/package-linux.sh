#!/usr/bin/env bash
set -euo pipefail

tar -zcvf "fldanplay-${TAG}-linux-amd64.tar.gz" -C build/linux/x64/release/bundle .

pkg_dir="fldanplay-${TAG}-linux-amd64"
mkdir "$pkg_dir"
cd "$pkg_dir"

mkdir -p opt/fldanplay usr/share/applications usr/share/icons/hicolor/512x512/apps
cp -r ../build/linux/x64/release/bundle/* opt/fldanplay
cp -r ../assets/linux/DEBIAN .
chmod 0755 DEBIAN/postinst DEBIAN/postrm

size_kb=$(du -s -b --apparent-size . | awk '{print int($1)}')
debian_size_kb=$(du -s -b --apparent-size DEBIAN | awk '{print int($1)}')
size_kb=$(awk -v size="$size_kb" -v debian="$debian_size_kb" 'BEGIN { print int((size - debian) / 1024 + 0.999) }')
version="${TAG#v}-1"

cat > DEBIAN/control <<EOF
Maintainer: huangshi10492
Package: fldanplay
Version: ${version}
Section: x11
Priority: optional
Architecture: amd64
Essential: no
Installed-Size: ${size_kb}
Description: fldanplay
Homepage: https://github.com/huangshi10492/flutter_danmaku_player
EOF

cp ../assets/linux/com.huangshi10492.fldanplay.desktop usr/share/applications/com.huangshi10492.fldanplay.desktop
cp ../assets/images/logo_round.png usr/share/icons/hicolor/512x512/apps/fldanplay.png

cd ..
dpkg-deb --build --root-owner-group "$pkg_dir"
