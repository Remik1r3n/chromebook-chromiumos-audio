#!/bin/sh
# Install recovery audio files on a ChromiumOS root filesystem.
set -eu

PACK=""
BOARD=""
MODE=""
ROOT="/"

usage() {
    echo "usage: $0 --pack <pack.tar.gz> [--board <name>] (--apply|--revert) [--root DIR]"
}

die() {
    echo "[setup_audio] $*" >&2
    exit 1
}

log() {
    echo "[setup_audio] $*"
}

safe_path() {
    case "$1" in
        ""|.|/*|..|../*|*/../*|*/..)
            return 1
            ;;
    esac
    return 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --pack|--board|--root)
            [ $# -ge 2 ] || die "missing value for $1"
            case "$1" in
                --pack)  PACK=$2 ;;
                --board) BOARD=$2 ;;
                --root)  ROOT=$2 ;;
            esac
            shift 2
            ;;
        --apply)
            [ -z "$MODE" ] || die "only one of --apply or --revert may be used"
            MODE=apply
            shift
            ;;
        --revert)
            [ -z "$MODE" ] || die "only one of --apply or --revert may be used"
            MODE=revert
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

[ -n "$MODE" ] || {
    usage
    exit 1
}

[ -d "$ROOT/etc" ] || die "target root has no etc directory: $ROOT"

if [ -z "$BOARD" ]; then
    BOARD=$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo unknown)
fi

BOARD=$(printf '%s' "$BOARD" | tr 'A-Z' 'a-z' | tr -d '[:space:]')

case "$BOARD" in
    ""|*[!a-z0-9_-]*)
        die "invalid board name: $BOARD"
        ;;
esac

DEST=${ROOT%/}
BACKUP="$DEST/usr/local/chromebook-audio-backup/$BOARD"

if [ "$MODE" = revert ]; then
    log "warning: revert is only a test feature"
    log "reverting board=$BOARD root=$ROOT backup=$BACKUP"

    [ -d "$BACKUP" ] || die "no backup for $BOARD at $BACKUP"

    if [ -f "$BACKUP/added.list" ]; then
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            safe_path "$p" || die "unsafe path in backup list: $p"

            rm -f "$DEST/$p" || die "cannot remove $p"
            log "removed $p"
        done < "$BACKUP/added.list"
    fi

    if [ -f "$BACKUP/original.list" ]; then
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            safe_path "$p" || die "unsafe path in backup list: $p"

            mkdir -p "$DEST/$(dirname "$p")" ||
                die "cannot create directory for $p"

            rm -f "$DEST/$p" || die "cannot remove current $p"
            cp -a "$BACKUP/original/$p" "$DEST/$p" ||
                die "cannot restore $p"

            log "restored $p"
        done < "$BACKUP/original.list"
    fi

    if [ -f "$BACKUP/added-dirs.list" ]; then
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            safe_path "$d" || die "unsafe directory in backup list: $d"
            rmdir "$DEST/$d" 2>/dev/null || true
        done < "$BACKUP/added-dirs.list"
    fi

    rm -rf "$BACKUP" || die "cannot remove backup directory $BACKUP"
    log "reverted $BOARD; reboot to reload the original audio driver"
    exit 0
fi

[ -n "$PACK" ] || die "need --pack <pack.tar.gz>"
[ -f "$PACK" ] || die "pack not found: $PACK"

if [ -e "$BACKUP" ] || [ -L "$BACKUP" ]; then
    die "backup already exists: $BACKUP; revert it before applying again"
fi

log "checking pack=$PACK board=$BOARD root=$ROOT"
tar tzf "$PACK" >/dev/null 2>&1 || die "invalid pack: $PACK"

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/chromebook-audio.XXXXXX") ||
    die "cannot create staging directory"

trap 'rm -rf "$STAGE"' 0
trap 'exit 1' 1 2 3 15

tar tzf "$PACK" | tr -d '\r' > "$STAGE/.members"

while IFS= read -r p; do
    case "$p" in
        ./*)
            p=${p#./}
            ;;
    esac

    safe_path "$p" || die "unsafe pack path: $p"
done < "$STAGE/.members"

tar xzf "$PACK" -C "$STAGE" ||
    die "cannot extract pack"

log "pack extracted to staging area"

INSTALLABLE=0

while IFS= read -r p; do
    case "$p" in
        ./*)
            p=${p#./}
            ;;
    esac

    [ "$p" != "MANIFEST.txt" ] || continue

    if [ -f "$STAGE/$p" ] || [ -L "$STAGE/$p" ]; then
        INSTALLABLE=1
        break
    fi
done < "$STAGE/.members"

[ "$INSTALLABLE" -eq 1 ] ||
    die "pack contains no installable files"

mkdir -p "$BACKUP/original" ||
    die "cannot create backup directory $BACKUP"

touch \
    "$BACKUP/original.list" \
    "$BACKUP/added.list" \
    "$BACKUP/added-dirs.list" ||
    die "cannot initialize backup lists in $BACKUP"

log "backup directory: $BACKUP"

record_path() {
    p=$1
    safe_path "$p" || die "unsafe destination path: $p"

    if grep -Fqx "$p" "$BACKUP/original.list" ||
       grep -Fqx "$p" "$BACKUP/added.list"; then
        return
    fi

    if [ -e "$DEST/$p" ] || [ -L "$DEST/$p" ]; then
        if [ -d "$DEST/$p" ] && [ ! -L "$DEST/$p" ]; then
            die "expected file, found directory: $DEST/$p"
        fi

        mkdir -p "$BACKUP/original/$(dirname "$p")" ||
            die "cannot create backup directory for $p"

        cp -a "$DEST/$p" "$BACKUP/original/$p" ||
            die "cannot back up $p"

        printf '%s\n' "$p" >> "$BACKUP/original.list"
        log "backed up $p"
    else
        printf '%s\n' "$p" >> "$BACKUP/added.list"
    fi
}

install_file() {
    source=$1
    relative=$2

    safe_path "$relative" || die "unsafe destination path: $relative"

    record_path "$relative"

    parent=$(dirname "$relative")
    while [ "$parent" != "." ] && [ ! -d "$DEST/$parent" ]; do
        printf '%s\n' "$parent" >> "$BACKUP/added-dirs.list"
        parent=$(dirname "$parent")
    done

    mkdir -p "$DEST/$(dirname "$relative")" ||
        die "cannot create directory for $relative"

    rm -f "$DEST/$relative" ||
        die "cannot replace $relative"

    cp -a "$source" "$DEST/$relative" ||
        die "cannot install $relative"

    log "installed $relative"
}

log "board=$BOARD pack=$PACK root=$ROOT"

for kind in regular symlink; do
    while IFS= read -r p; do
        case "$p" in
            ./*)
                p=${p#./}
                ;;
        esac

        [ "$p" != "MANIFEST.txt" ] || continue

        if [ "$kind" = regular ] &&
           [ -f "$STAGE/$p" ] &&
           [ ! -L "$STAGE/$p" ]; then
            install_file "$STAGE/$p" "$p"
        elif [ "$kind" = symlink ] &&
             [ -L "$STAGE/$p" ]; then
            install_file "$STAGE/$p" "$p"
        fi
    done < "$STAGE/.members"
done

# FydeOS forces legacy HDA with this file.
# The board pack supplies the DSP policy.
record_path "etc/modprobe.d/snd-intel-dspcfg.conf"
rm -f "$DEST/etc/modprobe.d/snd-intel-dspcfg.conf" ||
    die "cannot remove legacy HDA pin"

log "removed legacy HDA pin: etc/modprobe.d/snd-intel-dspcfg.conf"

if ! grep -rq \
    '^[[:space:]]*blacklist[[:space:]]*snd_hda_intel' \
    "$STAGE/etc/modprobe.d" 2>/dev/null; then

    record_path "etc/modprobe.d/alsa-hda.conf"

    printf '%s\n' 'blacklist snd_hda_intel' \
        > "$DEST/etc/modprobe.d/alsa-hda.conf" ||
        die "cannot install HDA blacklist"

    log "installed HDA blacklist: etc/modprobe.d/alsa-hda.conf"
fi

# Stock ChromeOS stores reusable UCM under .base or .<board> names.
REMAPPED=" "

for ucm in \
    "$STAGE"/usr/share/alsa/ucm/*."$BOARD" \
    "$STAGE"/usr/share/alsa/ucm/*.base
do
    [ -d "$ucm" ] || continue

    name=$(basename "$ucm")
    card=${name%.*}
    suffix=${name##*.}

    [ -f "$ucm/$card.$suffix.conf" ] || continue

    case "$REMAPPED" in
        *" $card "*)
            continue
            ;;
    esac

    for source in "$ucm"/*; do
        [ -f "$source" ] || [ -L "$source" ] || continue

        filename=$(basename "$source")

        if [ "$filename" = "$card.$suffix.conf" ]; then
            filename="$card.conf"
        fi

        install_file \
            "$source" \
            "usr/share/alsa/ucm/$card/$filename"
    done

    REMAPPED="$REMAPPED$card "
    log "UCM remap: $name -> $card"
done

# Generic FydeOS has no cros_config audio directory;
# CRAS reads configuration from /etc/cras/.
if [ -f "$DEST/etc/lsb-release" ] &&
   grep -qi fydeos "$DEST/etc/lsb-release" &&
   [ -d "$STAGE/etc/cras/$BOARD" ]; then

    config_dir=""

    if [ "$ROOT" = "/" ] &&
       command -v cros_config >/dev/null 2>&1; then
        config_dir=$(cros_config /audio/main cras-config-dir 2>/dev/null || true)
    fi

    if [ -z "$config_dir" ]; then
        for source in "$STAGE/etc/cras/$BOARD"/*; do
            [ -f "$source" ] || [ -L "$source" ] || continue

            install_file \
                "$source" \
                "etc/cras/$(basename "$source")"
        done

        log "CRAS config: /etc/cras/$BOARD -> /etc/cras"
    fi
fi

log "audio files applied; reboot, then run verify-audio.sh"