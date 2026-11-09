# usage: probe.sh <printf-cmd...>; prints width -> bytes written, exit code, errno msg
for w in 100 1073741823 1073741824 2147483583 2147483584 2147483640 2147483646 2147483647; do
	n=$("$@" "%0${w}d" 0 2>err | wc -c | tr -d ' '); rc=${PIPESTATUS[0]}
	echo "$* width=$w bytes=$n rc=$rc err=$(head -c 200 err)"
done
# literal prefix + width (the #2303 shape)
n=$("$@" "000000000%02147483640d" 0 2>err | wc -c | tr -d ' '); echo "$* prefix+2147483640 bytes=$n err=$(cat err)"
# Hannes' shape
n=$("$@" "%0715827883d" 0 0 0 2>err | wc -c | tr -d ' '); echo "$* 3x715827883 bytes=$n err=$(cat err)"
