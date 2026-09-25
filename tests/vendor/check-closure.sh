#!/bin/sh

set -eu

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
cd "$root"

status=0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

find src/vendor-gitg -type f ! -name meson.build | sed 's|^src/vendor-gitg/||' | sort > "$tmp/present"

grep -oE "'((libgitg|libgitg-ext)/[A-Za-z0-9/_-]+\.(vala|c|xml)|gitree-[a-z0-9-]+\.vala)'" src/vendor-gitg/meson.build \
	| tr -d "'" > "$tmp/listed.unsorted"
grep -oE '>ui/[A-Za-z0-9._-]+<' src/vendor-gitg/libgitg/resources/resources.xml \
	| tr -d '<>' | sed 's|^|libgitg/resources/|' >> "$tmp/listed.unsorted"
grep -E '\.c$' "$tmp/listed.unsorted" | sed 's/\.c$/.h/' > "$tmp/headers"
sort -u "$tmp/listed.unsorted" "$tmp/headers" > "$tmp/listed"

present=$(grep -v '^gitree-' "$tmp/present" || true)
unlisted=$(comm -23 "$tmp/present" "$tmp/listed")
missing=$(comm -13 "$tmp/present" "$tmp/listed")

if [ -n "$unlisted" ]; then
	echo "FAIL: vendored files present but not in meson.build or resources.xml:" >&2
	echo "$unlisted" | sed 's/^/  /' >&2
	status=1
fi

if [ -n "$missing" ]; then
	echo "FAIL: files in meson.build or resources.xml but not present:" >&2
	echo "$missing" | sed 's/^/  /' >&2
	status=1
fi

patch_name() {
	case "$1" in
		*.vala) echo "$(basename "$1" .vala).patch" ;;
		*) echo "$(basename "$1").patch" ;;
	esac
}

if [ -d vendor/upstream ]; then
	: > "$tmp/used"
	for f in $present; do
		cmp -s "vendor/upstream/$f" "src/vendor-gitg/$f" && continue
		name=$(patch_name "$f")
		echo "$name" >> "$tmp/used"
		if [ ! -f "vendor/patches/$name" ]; then
			echo "FAIL: $f differs from upstream but vendor/patches/$name is missing" >&2
			status=1
			continue
		fi
		mkdir -p "$tmp/apply/$(dirname "$f")"
		cp "vendor/upstream/$f" "$tmp/apply/$f"
		if ! patch -s -d "$tmp/apply" -p1 < "vendor/patches/$name" >/dev/null 2>&1 \
			|| ! cmp -s "$tmp/apply/$f" "src/vendor-gitg/$f"; then
			echo "FAIL: vendor/patches/$name does not turn upstream $f into the vendored file" >&2
			status=1
		fi
		if ! grep -qx "## $name" vendor/patches/README.md; then
			echo "FAIL: vendor/patches/README.md has no section for $name" >&2
			status=1
		fi
	done
	while read -r copy source; do
		if ! cmp -s "vendor/upstream/$source" "$copy"; then
			echo "FAIL: $copy is not byte for byte upstream $source" >&2
			status=1
		fi
	done <<-EOF
	src/gitree/resources/ui/style.css gitg/resources/ui/style.css
	vapi/config.vapi vapi/config.vapi
	vapi/gitg-platform-support.vapi vapi/gitg-platform-support.vapi
	vapi/gsettings-desktop-schemas.vapi vapi/gsettings-desktop-schemas.vapi
	EOF
	for p in vendor/patches/*.patch; do
		if ! grep -qx "$(basename "$p")" "$tmp/used"; then
			echo "FAIL: $p patches no vendored file that differs from upstream" >&2
			status=1
		fi
	done
else
	echo "note: vendor/upstream absent, skipping patch check (run vendor/fetch-upstream.sh)"
fi

[ $status -eq 0 ] && echo "closure consistent: $(echo "$present" | wc -l) vendored files"
exit $status
