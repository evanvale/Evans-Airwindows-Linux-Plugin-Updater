#!/usr/bin/env sh
set -u

# Evan's Airwindows Linux Plugin Updater v1.3
# Downloads and installs the latest consolidated Airwindows plugin pack for Linux
#
# Usage: ./airwindows_updater.sh [-q] [-v] [-h]
#   -q    Quiet mode (minimal output; only final success/failure message)
#   -v    Verbose mode (shows stdout/stderr from wget, curl, jq, and extraction tools)
#   -h    Show help and usage information
#
# First time setup:
#   Edit PLUGIN_DIR below or set it as an environment variable
#   Common CLAP locations: ~/.clap, /usr/lib/clap

PLUGIN_DIR="${PLUGIN_DIR:-}"

QUIET=0
VERBOSE=0

# -------- path helper --------
expand_path() {
    case "$1" in
        \~) printf '%s\n' "$HOME" ;;
        \~/*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# -------- logging --------
log()   { [ "$QUIET" -eq 0 ] && printf '[\033[32mSUCCESS\033[0m] %s\n' "$*"; }
info()  { [ "$QUIET" -eq 0 ] && printf '[\033[1;37mINFO\033[0m] %s\n' "$*"; }
error() { printf '[\033[31mERROR\033[0m] %s\n' "$*" >&2; }

while [ "$#" -gt 0 ]; do
    case "$1" in
        -q) QUIET=1 ;;
        -v) VERBOSE=1 ;;
        -h|--help)
            printf "Evan's Airwindows Linux Plugin Updater v1.3\n"
            printf "Downloads and installs the latest Airwindows plugin pack\n\n"
            printf "Usage:\n"
            printf "  %s [-q] [-v] [-h]\n" "$0"
            printf "  PLUGIN_DIR=~/.clap %s\n\n" "$0"
            printf "Options:\n"
            printf "  -q        Quiet mode (minimal output)\n"
            printf "  -v        Verbose mode (show command output)\n"
            printf "  -h, --help    Show this help message\n\n"
            printf "First time setup:\n"
            printf "  Edit PLUGIN_DIR in this script or set it as an environment variable\n"
            printf "  Common CLAP locations: ~/.clap, /usr/lib/clap\n"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Expand static or environment PLUGIN_DIR
[ -n "$PLUGIN_DIR" ] && PLUGIN_DIR=$(expand_path "$PLUGIN_DIR")

# -------- status & traps --------
status=0
TEMP_DIR=$(mktemp -d 2>/dev/null || (mkdir -p "/tmp/airwindows-$$" && echo "/tmp/airwindows-$$"))

cleanup() { rm -rf "$TEMP_DIR"; }
finish() { [ "$status" -ne 0 ] && printf '[\033[31mERROR\033[0m] Airwindows plugins update failed.\n'; }
trap 'cleanup; finish' EXIT

fatal() { error "$*"; status=1; exit 1; }

# -------- check plugin folder --------
if [ -z "$PLUGIN_DIR" ]; then
    if [ "$QUIET" -eq 1 ]; then
        fatal "PLUGIN_DIR not set. Set PLUGIN_DIR environment variable and rerun."
    else
        info "No plugin directory set. Common CLAP locations:"
        info "  • ~/.clap (user CLAP plugins)"
        info "  • /usr/lib/clap (system-wide CLAP)"
        info ""
        info "You can either:"
        info "  1. Set PLUGIN_DIR environment variable:"
        info "     export PLUGIN_DIR=~/.clap"
        info "  2. Edit this script and change PLUGIN_DIR at the top"
        info "  3. Enter a path now"
        printf "Enter plugin directory path (or press Enter to exit): "
        read -r answer
        if [ -n "$answer" ]; then
            PLUGIN_DIR=$(expand_path "$answer")
        else
            fatal "Please set PLUGIN_DIR and rerun"
        fi
    fi
fi

if [ ! -d "$PLUGIN_DIR" ]; then
    if [ "$QUIET" -eq 1 ]; then
        fatal "Plugin folder '$PLUGIN_DIR' not found."
    else
        info "Directory '$PLUGIN_DIR' doesn't exist."
        printf "Enter your actual plugin directory path: "
        read -r new_path
        if [ -n "$new_path" ]; then
            PLUGIN_DIR=$(expand_path "$new_path")
            if [ ! -d "$PLUGIN_DIR" ]; then
                printf "Directory '$PLUGIN_DIR' doesn't exist. Create it? [Y/n]: "
                read -r answer
                if [ "$answer" != "n" ] && [ "$answer" != "N" ]; then
                    mkdir -p "$PLUGIN_DIR" || fatal "Failed to create directory $PLUGIN_DIR"
                    log "Created plugin directory: $PLUGIN_DIR"
                else
                    fatal "Cannot proceed without plugin directory"
                fi
            fi
        else
            fatal "No path entered"
        fi
    fi
else
    [ "$QUIET" -eq 0 ] && log "Target plugin folder found: $PLUGIN_DIR"
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# -------- downloader --------
download() {
    url=$1; outfile=$2
    if need_cmd wget; then
        if [ "$VERBOSE" -eq 1 ]; then
            wget "$url" -O "$outfile" || fatal "wget download failed"
        else
            wget -q "$url" -O "$outfile" || fatal "wget download failed"
        fi
        log "Download completed using wget"
    elif need_cmd curl; then
        if [ "$VERBOSE" -eq 1 ]; then
            curl -L "$url" -o "$outfile" || fatal "curl download failed"
        else
            curl -L -s "$url" -o "$outfile" || fatal "curl download failed"
        fi
        log "Download completed using curl"
    else
        fatal "No downloader found (wget or curl)."
    fi
}

# -------- extractor --------
extract_zip() {
    file=$1; dest=$2
    for cmd in bsdtar unzip 7z 7za; do
        if need_cmd "$cmd"; then
            case "$cmd" in
                bsdtar)
                    if bsdtar -xf "$file" -C "$dest"; then
                        log "Extraction completed using bsdtar"; return 0
                    else info "bsdtar failed, trying next extractor"; fi ;;
                unzip)
                    if unzip -q "$file" -d "$dest"; then
                        log "Extraction completed using unzip"; return 0
                    else info "unzip failed, trying next extractor"; fi ;;
                7z|7za)
                    if [ "$VERBOSE" -eq 1 ]; then
                        if "$cmd" x -y -o"$dest" "$file"; then
                            log "Extraction completed using $cmd"; return 0
                        else info "$cmd failed, trying next extractor"; fi
                    else
                        if "$cmd" x -y -o"$dest" "$file" >/dev/null 2>&1; then
                            log "Extraction completed using $cmd"; return 0
                        else info "$cmd failed, trying next extractor"; fi
                    fi ;;
            esac
        else
            info "$cmd not found, trying next extractor"
        fi
    done
    if need_cmd busybox && busybox unzip -h >/dev/null 2>&1; then
        if busybox unzip -q "$file" -d "$dest"; then
            log "Extraction completed using busybox unzip"; return 0
        else
            info "busybox unzip failed, no extractors left"
        fi
    else
        info "busybox unzip not available, no extractors left"
    fi
    fatal "No suitable extractor found (bsdtar, unzip, 7z, 7za, busybox)."
}

# -------- GitHub API / HTML fallback --------
url=""
get_url_api() {
    api_url="https://api.github.com/repos/baconpaul/airwin2rack/releases/tags/DAWPlugin"
    if need_cmd jq; then
        if need_cmd wget; then
            url=$(wget -q -O - --header="Accept: application/vnd.github+json" "$api_url" \
                | jq -r '.assets[]?.browser_download_url? // empty | select(test("Linux\\.zip"))' | head -n 1)
        elif need_cmd curl; then
            url=$(curl -s -H "Accept: application/vnd.github+json" "$api_url" \
                | jq -r '.assets[]?.browser_download_url? // empty | select(test("Linux\\.zip"))' | head -n 1)
        fi
        [ -n "$url" ] && log "Download URL found via API (jq)" || info "jq failed, trying fallback"
    else
        info "jq not found, trying sed fallback"
        if need_cmd wget; then
            url=$(wget -q -O - --header="Accept: application/vnd.github+json" "$api_url" \
                | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*Linux\.zip[^"]*\)".*/\1/p' | head -n 1)
        elif need_cmd curl; then
            url=$(curl -s -H "Accept: application/vnd.github+json" "$api_url" \
                | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*Linux\.zip[^"]*\)".*/\1/p' | head -n 1)
        fi
        [ -n "$url" ] && log "Download URL found via API (sed)" || info "fallback failed"
    fi
}
get_url_html() {
    if need_cmd wget; then
        wget -q -O - https://github.com/baconpaul/airwin2rack/releases/tag/DAWPlugin \
            | grep -o '/baconpaul/airwin2rack/[^"]*Linux\.zip' | head -n 1 \
            | sed 's|^|https://github.com|'
    elif need_cmd curl; then
        curl -s https://github.com/baconpaul/airwin2rack/releases/tag/DAWPlugin \
            | grep -o '/baconpaul/airwin2rack/[^"]*Linux\.zip' | head -n 1 \
            | sed 's|^|https://github.com|'
    fi
}

# -------- pick URL --------
get_url_api
[ -z "$url" ] && url=$(get_url_html)
[ -n "$url" ] || fatal "Could not determine download URL."
log "Download URL ready"

# -------- download --------
zipfile="$TEMP_DIR/airwindows.zip"
download "$url" "$zipfile"

# -------- verify download --------
if [ ! -f "$zipfile" ] || [ ! -s "$zipfile" ]; then
    fatal "Download failed or empty file"
fi
log "Download verification: OK"

# -------- extract --------
info "Extracting plugins..."
extract_zip "$zipfile" "$TEMP_DIR"

# -------- move plugins --------
clap_file=$(find "$TEMP_DIR" -name "Airwindows Consolidated.clap" | head -n 1)

[ -n "$clap_file" ] || fatal "Airwindows Consolidated.clap not found in downloaded zip"

mkdir -p "$PLUGIN_DIR" || fatal "Failed to ensure plugin directory exists: $PLUGIN_DIR"

if cp -r "$clap_file" "$PLUGIN_DIR/"; then
    log "Installed Airwindows Consolidated.clap to $PLUGIN_DIR"
else
    fatal "Failed to copy $clap_file to $PLUGIN_DIR (check permissions or disk space)"
fi
