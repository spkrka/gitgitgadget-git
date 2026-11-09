t() { echo "== $1"; shift; /usr/bin/time "$@" 2>&1 >/dev/null | tail -20; }
tm=/usr/bin/time; [ "$(uname)" = Darwin ] && tm="/usr/bin/time -l" || tm="/usr/bin/time -v"
run() { echo "== $1"; shift; $tm "$@" >out 2>time.txt; grep -Ei "real|elapsed|maximum resident" time.txt; echo "bytes=$(wc -c <out | tr -d ' ')"; rm -f out; }
run "sh printf 1x1GiB" /bin/sh -c 'printf %01073741824d 0'
run "sh printf 2x1GiB+1" /bin/sh -c 'printf %01073741824d 0 0; printf %01d 0'
run "sh printf 3x715827883" /bin/sh -c 'printf %0715827883d 0 0 0'
run "sh printf 128x16MiB" /bin/sh -c 'i=0; while [ $i -lt 128 ]; do printf %016777216d 0; i=$((i+1)); done'
run "head -c | tr (2GiB)" /bin/sh -c 'head -c 2147483649 /dev/zero | tr "\000" 1'
