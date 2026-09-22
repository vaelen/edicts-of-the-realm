#!/usr/bin/env bash
# Manage what the Paradox Launcher sees as this mod.
#   scripts/launcher-mod.sh upload   stage a clean copy of HEAD in the launcher mod dir and point the launcher at it
#   scripts/launcher-mod.sh dev      point the launcher back at this repo (hot reload while editing)
#   scripts/launcher-mod.sh zip      build edicts_of_the_realm-<version>.zip from HEAD for the GitHub release
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
moddir="$HOME/.local/share/Paradox Interactive/Crusader Kings III/mod"
stage="$moddir/edicts_of_the_realm"
pointer="$moddir/edicts_of_the_realm.mod"
files=(descriptor.mod common localization thumbnail.jpg Credits.txt README.md CHANGELOG.md)
version=$(sed -n 's/^version="\(.*\)"/\1/p' "$repo/descriptor.mod")

case "${1:-}" in
	upload)
		rm -rf "$stage" && mkdir -p "$stage"
		git -C "$repo" archive HEAD -- "${files[@]}" | tar -x -C "$stage"
		target=$stage ;;
	dev)
		target=$repo ;;
	zip)
		out="$repo/edicts_of_the_realm-$version.zip"
		git -C "$repo" archive --format=zip --prefix=edicts_of_the_realm/ -o "$out" HEAD -- "${files[@]}"
		echo "built $out"; exit 0 ;;
	*)
		echo "usage: $0 upload|dev|zip" >&2; exit 1 ;;
esac

{ cat "$repo/descriptor.mod"; printf '\npath="%s"\n' "$target"; } > "$pointer"
echo "launcher pointer -> $target"
