#!/bin/sh

set -eu

here=$(dirname "$(readlink -f "$0")")
root=$(dirname "$here")
out=${TMPDIR:-/tmp}/gitree-closure
rm -rf "$out"
mkdir -p "$out"

cat > "$out/config.h" <<'EOF'
#define APPLICATION_ID "io.github.li9i.gitree"
#define PROFILE ""
#define GETTEXT_PACKAGE "gitree"
#define PACKAGE_NAME "gitree"
#define PACKAGE_VERSION "0.1.0"
#define PACKAGE_URL ""
#define GITG_DATADIR "/usr/share/gitree"
#define GITG_LOCALEDIR "/usr/share/locale"
#define GITG_LIBDIR "/usr/lib/gitree"
#define VERSION "0.1.0"
#define PLATFORM_NAME "unix"
EOF

packages="gee-0.8 gio-2.0 glib-2.0 gtk+-3.0 gdk-3.0 gtksourceview-4 libgit2-glib-1.0 gsettings-desktop-schemas"

valac -C -d "$out" \
	--vapidir "$root/vapi" \
	--pkg config \
	--pkg gitg-platform-support \
	$(for p in $packages; do printf -- '--pkg %s ' "$p"; done) \
	--target-glib 2.68 \
	--gresources "$root/src/vendor-gitg/libgitg/resources/resources.xml" \
	--gresourcesdir "$root/src/vendor-gitg/libgitg/resources" \
	"$@" \
	$(find "$root/src/vendor-gitg" -name '*.vala' | sort)

cflags="$(pkg-config --cflags $packages) -I$out -I$root/src/vendor-gitg -include $out/config.h"
cflags="$cflags -Wno-switch -Wno-unused-parameter -Wno-incompatible-pointer-types"
cflags="$cflags -Wno-discarded-qualifiers -Wno-unused-but-set-variable -Wno-deprecated-declarations"

for c in $(find "$out" -name '*.c' | sort) "$root/src/vendor-gitg/libgitg/gitg-platform-support.c"; do
	cc -c $cflags -o "$out/$(basename "$c" .c).o" "$c"
done

echo "closure compiled: $(find "$out" -name '*.o' | wc -l) object files in $out"
