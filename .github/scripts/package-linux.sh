#!/usr/bin/env bash
set -euo pipefail

# package-linux.sh [x64|arm64]
flutter_arch="${1:-x64}"

case "$flutter_arch" in
  x64)
    artifact_arch="amd64"
    deb_arch="amd64"
    ;;
  arm64)
    artifact_arch="arm64"
    deb_arch="arm64"
    ;;
  *)
    echo "不支持的架构: $flutter_arch（仅支持 x64 / arm64）" >&2
    exit 1
    ;;
esac

bundle_dir="build/linux/${flutter_arch}/release/bundle"
if [ ! -d "$bundle_dir" ]; then
  echo "未找到 ${bundle_dir}，请先执行 flutter build linux --release --target-platform linux-${flutter_arch}" >&2
  exit 1
fi

tar -zcvf "fldanplay-${TAG}-linux-${artifact_arch}.tar.gz" -C "$bundle_dir" .

pkg_dir="fldanplay-${TAG}-linux-${artifact_arch}"
rm -rf "$pkg_dir"
mkdir "$pkg_dir"
cd "$pkg_dir"

mkdir -p opt/fldanplay usr/share/applications usr/share/icons/hicolor/512x512/apps
cp -r "../${bundle_dir}"/* opt/fldanplay
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
Architecture: ${deb_arch}
Essential: no
Installed-Size: ${size_kb}
Description: fldanplay
Homepage: https://github.com/huangshi10492/flutter_danmaku_player
EOF

cp ../assets/linux/com.huangshi10492.fldanplay.desktop usr/share/applications/com.huangshi10492.fldanplay.desktop
cp ../assets/images/logo_round.png usr/share/icons/hicolor/512x512/apps/fldanplay.png

cd ..
dpkg-deb --build --root-owner-group "$pkg_dir"
