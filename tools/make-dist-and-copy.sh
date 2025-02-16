#!/usr/bin/env bash

set -euo pipefail

PACKAGE_PREFIX="papirus-icon-theme"
TARGET_DIR="${HOME}/.local/papirus-icons"
export XZ_OPT="-3 -e -T0"

PROGNAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
GIT_ROOT="$(realpath "$SCRIPT_DIR/..")"
BUILD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/papirus-dist"

if ! command -v papirus-folders >/dev/null; then
	echo "papirus-folders script is not installed. Install it first." >&2
	exit 1
fi

usage() {
	cat <<- EOF
	This script copies theme files to a specific directory for a single color.

	USAGE
	  $ $PROGNAME [-d DIRECTORY] [-v VERSION] [-c COLOR] [-t THEMES]

	OPTIONS
	  -d DIRECTORY  target directory for the theme files (Default: $TARGET_DIR)
	  -v VERSION    existing git tag or branch name (Default: last release)
	  -c COLOR      specify the color variant to copy
	  -t THEMES     specify a list of themes to include (e.g., "Papirus Papirus-Dark")
	  -h            show this help

	EXAMPLES
	  $ $PROGNAME -c bluegrey -t "Papirus Papirus-Dark"
	  $ $PROGNAME -d ~/my-icons -v master -c red -t "Papirus-Light ePapirus"
	EOF

	exit "${1:-0}"
}

while getopts ":hd:v:c:t:" opt; do
	case "$opt" in
	h)
		usage 0
		;;
	d)
		TARGET_DIR="${OPTARG}"
		;;
	v)
		VERSION="${OPTARG}"
		;;
	c)
		COLOR="${OPTARG}"
		;;
	t)
		THEMES="${OPTARG}"
		;;
	:)
		echo "Error: option -$OPTARG requires an argument" >&2
		usage 2
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		usage 2
		;;
	esac
done

shift $((OPTIND-1))

# Ensure COLOR is provided
if [ -z "${COLOR}" ]; then
	echo "Error: -c COLOR is required" >&2
	usage 2
fi

# If THEMES is not provided, default to all themes
if [ -z "${THEMES}" ]; then
	mapfile -t ICON_THEMES < <(
		find "$GIT_ROOT" -type f -name 'index.theme' -printf '%h\n'
	)
else
	# Split the THEMES string into an array
	ICON_THEMES=($THEMES)
fi

if [ -z "${VERSION:-}" ]; then
	VERSION="$(git -C "$GIT_ROOT" tag -l --sort=-version:refname | head -1)"
fi

echo "Start copying files for $VERSION version and color $COLOR"

if [ -e "$BUILD_DIR" ]; then
	echo "Remove '$BUILD_DIR' ..."
	rm -r "${BUILD_DIR?}"
fi

mkdir -p "$BUILD_DIR"

echo "Extracting files to '$BUILD_DIR' ..."
git -C "$GIT_ROOT" archive --format=tar.gz "$VERSION" -- "${ICON_THEMES[@]}" | tar -C "$BUILD_DIR" -xzf -

cd "$BUILD_DIR"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Change folder color
DISABLE_UPDATE_ICON_CACHE=1 papirus-folders --once --color "$COLOR"

echo "Copying files for color '$COLOR' to '$TARGET_DIR' ..."
cp -R "${ICON_THEMES[@]}" "$TARGET_DIR"

if [ -e "$BUILD_DIR" ]; then
	echo "Cleanup '$BUILD_DIR' ..."
	rm -r "${BUILD_DIR?}"
fi
