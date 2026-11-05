#!/bin/sh
# Read-Only audio health check.
# Use it when reporting problems
set -eu
say() { printf "%s\n" "$*"; }
say "=== DMI ==="
dmidecode || true
say ""
say "=== boot and DSP selection ==="
uname -r 2>/dev/null || true
cat /proc/cmdline 2>/dev/null || true
if [ -r /sys/module/snd_intel_dspcfg/parameters/dsp_driver ]; then
  say "snd_intel_dspcfg.dsp_driver=$(cat /sys/module/snd_intel_dspcfg/parameters/dsp_driver)"
fi
say ""
say "=== cards ==="
cat /proc/asound/cards 2>/dev/null || say "(no /proc/asound/cards)"
say ""
say "=== aplay/arecord ==="
aplay -l 2>&1 || true
arecord -l 2>&1 || true
say ""
say "=== modules ==="
lsmod 2>/dev/null | grep -i -E "snd|sof|sst|avs|hda|rt5|nau|max98|cs42|da7219" || say "(no matching modules)"
say ""
say "=== dmesg audio ==="
dmesg 2>/dev/null | grep -i -E "audio|snd|sof|sst|avs|hda|dsp|tplg|rt5|nau|max98|firmware.*(fail|error|missing|abort)" | tail -n 60 || say "(dmesg unavailable)"
say ""
say "=== modprobe ==="
ls /etc/modprobe.d/ 2>/dev/null | grep -i -E "alsa|snd|sof|sst|avs|hda" || say "(no alsa/snd modprobe files)"
grep -r . /etc/modprobe.d/ 2>/dev/null | grep -i -E "blacklist|dsp_driver|dmic" || true
say ""
say "=== firmware ==="
ls /lib/firmware/intel/ 2>/dev/null | grep -i -E "sst|dsp_fw|sof" || say "(no intel dsp fw)"
ls /lib/firmware/intel/sof-tplg/ 2>/dev/null | head -20 || true
ls /lib/firmware/amd/sof-tplg/ 2>/dev/null | head -20 || true
ls -l /lib/firmware/intel/sof/community/sof-cml.ri /lib/firmware/intel/sof/community/sof-cnl.ri /lib/firmware/intel/sof-tplg/sof-cml-rt5682-max98357a.tplg 2>&1 || true
say ""
say "=== UCM ==="
ls /usr/share/alsa/ucm/ 2>/dev/null || say "(no /usr/share/alsa/ucm)"
ls /usr/share/alsa/ucm2/ 2>/dev/null | head -30 || true
alsaucm listcards 2>&1 || true
say ""
say "=== CRAS ==="
ls /etc/cras/ 2>/dev/null || say "(no /etc/cras)"
if command -v cros_config >/dev/null 2>&1; then
  say "cras-config-dir=$(cros_config /audio/main cras-config-dir 2>/dev/null || true)"
  say "ucm-suffix=$(cros_config /audio/main ucm-suffix 2>/dev/null || true)"
fi
for f in /etc/cras/board.ini /etc/cras/dsp.ini; do
  if [ -f "$f" ]; then ls -l "$f"; else say "missing: $f"; fi
done
(cras_test_client --dump_server_info 2>&1 | head -60) || true
say ""
say "done."
