#!/bin/sh
# Build a portable board audio pack from any
# ChromeOS recovery .bin. 
# Run it in a full Linux environment, like your Linux PC or Crostini. 
# Windows with Git-Bash and 7z should also works.

set -eu

RECO=""
OUT=""
BOARD_HINT=""
LISTONLY=0

usage() {
  echo "usage: $0 --recovery <recovery.bin> --out <pack.tar.gz> [--board <name>] [--list-only]"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --recovery) RECO="${2:-}"; shift 2;;
    --out) OUT="${2:-}"; shift 2;;
    --board) BOARD_HINT="${2:-}"; shift 2;;
    --list-only) LISTONLY=1; shift;;
    -h|--help) usage; exit 0;;
    *) usage; exit 1;;
  esac
done

if [ -z "$RECO" ]; then echo "need --recovery <recovery.bin>"; exit 1; fi
if [ ! -f "$RECO" ]; then echo "recovery image not found: $RECO"; exit 1; fi
command -v 7z >/dev/null 2>&1 || { echo "need 7z on PATH"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "need python3 on PATH"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

log() { echo "[make_audio_pack] $*"; }
log "recovery: $RECO"

ROOTIMG="$WORK/ROOT-A.img"
log "extracting ROOT-A partition (reads multi-GB image, takes a while)..."
if ! 7z x "-o$WORK" "$RECO" 2.ROOT-A.img -y >/dev/null 2>&1; then
  7z x "-o$WORK" "$RECO" ROOT-A.img -y >/dev/null 2>&1 || {
    echo "ROOT-A extraction failed"
    7z l "$RECO" | head -30
    exit 1
  }
  mv "$WORK/ROOT-A.img" "$ROOTIMG" 2>/dev/null || true
else
  mv "$WORK/2.ROOT-A.img" "$ROOTIMG"
fi
log "ROOT-A size: $(du -h "$ROOTIMG" | cut -f1)"

AUD="$WORK/audio"
mkdir -p "$AUD"
log "extracting audio slice..."
7z x "-o$AUD" "$ROOTIMG" etc/modprobe.d etc/cras usr/share/alsa/ucm lib/firmware/intel/sof-tplg lib/firmware/intel/sof -y >/dev/null 2>&1
7z x "-o$AUD" "$ROOTIMG" lib/firmware/intel/fw_sst_0f28.bin lib/firmware/intel/fw_sst_22a8.bin lib/firmware/intel/dsp_fw_release.bin -y >/dev/null 2>&1 || true
7z x "-o$AUD" "$ROOTIMG" etc/lsb-release -y >/dev/null 2>&1 || true

mkdir -p "$AUD/etc/modprobe.d.keep"
for f in "$AUD"/etc/modprobe.d/alsa*.conf; do
  if [ -f "$f" ]; then cp -a "$f" "$AUD/etc/modprobe.d.keep/"; fi
done
rm -rf "$AUD/etc/modprobe.d"
mv "$AUD/etc/modprobe.d.keep" "$AUD/etc/modprobe.d"

if [ "$LISTONLY" -eq 1 ]; then
  log "audio slice:"
  (cd "$AUD" && find . | sort | head -60)
  log "(list-only, no pack written)"
  exit 0
fi

if [ -z "$OUT" ]; then echo "need --out <pack.tar.gz>"; exit 1; fi

BOARD=""
if [ -n "$BOARD_HINT" ]; then BOARD="$BOARD_HINT"; fi
if [ -f "$AUD/etc/lsb-release" ]; then
  B="$(grep -o "CHROMEOS_RELEASE_BOARD=[^ ]*" "$AUD/etc/lsb-release" 2>/dev/null | cut -d= -f2 | cut -d- -f1 || true)"
  if [ -n "$B" ] && [ "$B" != "amd64-fydeos_iris" ]; then BOARD="$B"; fi
fi
if [ -z "$BOARD" ]; then
  BOARD="$(basename "$RECO" | tr "A-Z" "a-z" | sed "s#.*chromeos_[0-9.]*_##;s#_recovery_.*##" || echo unknown)"
fi
log "board: ${BOARD:-unknown}"
ls "$AUD/etc/modprobe.d"
du -sh "$AUD"

log "packing $OUT ..."
RECO_BASE="$(basename "$RECO")"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$AUD" "$OUT" "$BOARD" "$RECO_BASE" "$BUILD_DATE" <<'PYEOF'
import tarfile, pathlib, sys, io
src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
board, reco, date = sys.argv[3], sys.argv[4], sys.argv[5]
names = []
with tarfile.open(out, "w:gz") as tf:
    for p in sorted(src.rglob("*")):
        rel = p.relative_to(src).as_posix()
        if rel in (".",):
            continue
        ti = tf.gettarinfo(str(p), arcname=rel)
        ti.uid = 0
        ti.gid = 0
        ti.uname = "root"
        ti.gname = "root"
        ti.mtime = 0
        if p.is_symlink():
            # 7z creates Windows-style relative links when run on Windows.
            ti.linkname = p.readlink().as_posix()
            tf.addfile(ti)
        elif p.is_dir():
            tf.addfile(ti)
        else:
            with open(p, "rb") as f:
                tf.addfile(ti, f)
        names.append(rel)
    man = "board=" + board + "\nsource_recovery=" + reco + "\nbuilt_utc=" + date + "\nentries=" + str(len(names)) + "\n"
    man += "layout: etc/modprobe.d(alsa*.conf) etc/cras usr/share/alsa/ucm lib/firmware/intel/{sof,sof-tplg[,fw_sst*,dsp_fw*]}\n"
    ti = tarfile.TarInfo("MANIFEST.txt")
    d = man.encode()
    ti.size = len(d)
    ti.mtime = 0
    ti.uid = 0
    ti.gid = 0
    tf.addfile(ti, io.BytesIO(d))
print("pack entries:", len(tarfile.open(out).getnames()))
PYEOF
log "wrote $OUT ($(du -h "$OUT" | cut -f1))"
tar tzf "$OUT" | head -30
log "done. 