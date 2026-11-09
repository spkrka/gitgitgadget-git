# write 2147483649 ASCII zeros with a given chunk size, using /bin/sh printf
total=2147483649
tm="/usr/bin/time -p"; [ "$(uname)" = Darwin ] && rss="/usr/bin/time -l" || rss="/usr/bin/time -v"
for chunk in 65536 1048576 8388608 16777216 67108864 134217728 536870912 1073741824; do
	$rss /bin/sh -c '
		n=$1 c=$2
		while test "$n" -gt 0; do
			k=$(( n > c ? c : n ))
			printf "%0${k}d" 0 || exit 1
			n=$(( n - k ))
		done' sh $total $chunk >out 2>time.txt
	real=$(grep -Eo "[0-9.]+ real|Elapsed.*: [0-9:.]+" time.txt | head -1)
	mem=$(grep -Ei "maximum resident" time.txt | grep -Eo "[0-9]+" | head -1)
	echo "chunk=$chunk bytes=$(wc -c <out | tr -d ' ') time=[$real] maxrss=$mem"
	rm -f out
done
