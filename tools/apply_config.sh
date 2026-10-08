#!/bin/sh
# Rewrites project.godot for one platform:  tools/apply_config.sh pc|phone|vr
#
# project.godot is the single project configuration. The few settings that differ between
# platforms are listed in configs/<platform>.cfg, in the same [section] / key=value form, and
# this script overwrites just those keys. A key that project.godot does not have is an error,
# so a renamed setting cannot be dropped silently.
set -eu
cd "$(dirname "$0")/.."
platform="${1:-}"
overrides="configs/$platform.cfg"
if [ -z "$platform" ] || [ ! -f "$overrides" ]; then
    echo "usage: tools/apply_config.sh pc|phone|vr" >&2
    exit 2
fi
awk -v overrides="$overrides" '
function trim(s) { sub(/\r$/, "", s); return s }
BEGIN {
    section = ""
    while ((getline line < overrides) > 0) {
        line = trim(line)
        if (line ~ /^\[.*\]$/) { section = line; continue }
        if (line == "" || line ~ /^;/) continue
        eq = index(line, "=")
        key = section SUBSEP substr(line, 1, eq - 1)
        value[key] = substr(line, eq + 1)
        pending[key] = 1
    }
    section = ""
}
{
    line = trim($0)
    if (line ~ /^\[.*\]$/) section = line
    eq = index(line, "=")
    if (eq > 0) {
        key = section SUBSEP substr(line, 1, eq - 1)
        if (key in value) {
            line = substr(line, 1, eq) value[key]
            delete pending[key]
        }
    }
    print line
}
END {
    missing = 0
    for (key in pending) {
        split(key, parts, SUBSEP)
        print "apply_config: project.godot has no " parts[1] " " parts[2] > "/dev/stderr"
        missing = 1
    }
    exit missing
}' project.godot > project.godot.tmp
mv project.godot.tmp project.godot
echo "project.godot -> $platform"
