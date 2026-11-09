ok() { test "$(/bin/sh -c 'printf "%0${1}d" 0' sh "$1" | wc -c | tr -d ' ')" = "$1"; }
lo=2147483584 hi=2147483640   # lo works, hi fails
ok $lo || { echo "lo $lo unexpectedly fails"; exit 1; }
ok $hi && { echo "hi $hi unexpectedly works"; exit 1; }
while [ $((hi - lo)) -gt 1 ]; do
	mid=$(( (lo + hi) / 2 ))
	if ok $mid; then lo=$mid; else hi=$mid; fi
done
echo "max working width=$lo first failing=$hi INT_MAX-lo=$((2147483647 - lo))"
