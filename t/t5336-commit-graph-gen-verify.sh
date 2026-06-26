#!/bin/sh

test_description='commit-graph generation number verification and GFIX chunk'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-commit-graph.sh

GIT_TEST_COMMIT_GRAPH_CHANGED_PATHS=0

# Zero the GFIX level in a commit-graph file so the graph appears
# to have been written by an old git without the truncation fix.
# GFIX data (4 bytes) sits just before the footer hash.
clear_gfix_level() {
	graph_file=$1
	hash_len=$(test_oid rawsz) &&
	file_size=$(wc -c <"$graph_file") &&
	gfix_offset=$(($file_size - $hash_len - 4)) &&
	printf "\0\0\0\0" | dd of="$graph_file" bs=1 \
		seek="$gfix_offset" conv=notrunc 2>/dev/null
}

# Corrupt generation data by writing 0xff bytes over the GDA2
# chunk region. With generation v2, the GDA2 stores offsets
# added to commit dates. Setting parent offsets to 0xffffffff
# makes gen(parent) huge, violating monotonicity.
# The GDA2 chunk starts right after CDAT in the standard layout.
# Also clears GFIX level so verification runs.
corrupt_generation_data() {
	graph_file=$1
	hash_len=$(test_oid rawsz) &&
	num_chunks=$(test-tool read-graph | sed -n "s/^header:.*[0-9] \([0-9]*\) 0$/\1/p") &&
	toc_size=$(($num_chunks * 12)) &&
	fanout_offset=$((8 + $toc_size)) &&
	lookup_offset=$(($fanout_offset + 256 * 4)) &&
	num_commits=$(test-tool read-graph | sed -n "s/^num_commits: //p") &&
	cdat_offset=$(($lookup_offset + $num_commits * $hash_len)) &&
	entry_width=$(($hash_len + 16)) &&
	gda2_offset=$(($cdat_offset + $num_commits * $entry_width)) &&
	# Write 0xff over first entry (root commit gets huge gen)
	printf "\x7f\xff\xff\xff" | dd of="$graph_file" bs=1 \
		seek="$gda2_offset" conv=notrunc 2>/dev/null &&
	clear_gfix_level "$graph_file"
}

test_expect_success 'setup' '
	test_commit A &&
	test_commit B &&
	test_commit C &&
	git commit-graph write --reachable
'

test_expect_success 'GFIX chunk is written' '
	test-tool read-graph >output &&
	grep -q "gfix" output
'

test_expect_success 'verify-generations reports ok on clean graph' '
	test-tool read-graph verify-generations >output &&
	grep "result: ok" output
'

test_expect_success 'sidecar .gfix created for graph without GFIX level' '
	graph_file=.git/objects/info/commit-graph &&
	test_when_finished "chmod u+w \"$graph_file\" && \
		cp commit-graph-orig \"$graph_file\" && \
		rm -f \"$graph_file.gfix\"" &&
	cp -f "$graph_file" commit-graph-orig &&
	chmod u+w "$graph_file" &&
	clear_gfix_level "$graph_file" &&
	rm -f "$graph_file.gfix" &&

	GIT_TEST_FORCE_GENERATION_VERIFY=1 \
		git log --oneline -1 &&
	test_path_is_file "$graph_file.gfix"
'

test_expect_success 'sidecar .gfix skips verification on next load' '
	graph_file=.git/objects/info/commit-graph &&
	test_when_finished "chmod u+w \"$graph_file\" && \
		cp commit-graph-orig \"$graph_file\" && \
		rm -f \"$graph_file.gfix\"" &&
	cp -f "$graph_file" commit-graph-orig &&
	chmod u+w "$graph_file" &&
	clear_gfix_level "$graph_file" &&

	# Create sidecar manually
	>"$graph_file.gfix" &&
	git log --oneline -1
'

test_expect_success 'no sidecar when graph has GFIX level' '
	graph_file=.git/objects/info/commit-graph &&
	rm -f "$graph_file.gfix" &&

	GIT_TEST_FORCE_GENERATION_VERIFY=1 \
		git log --oneline -1 &&

	test_path_is_missing "$graph_file.gfix"
'

test_expect_success 'GIT_TEST_FORCE_GENERATION_VERIFY forces check' '
	GIT_TEST_FORCE_GENERATION_VERIFY=1 \
		git log --oneline -1
'

test_expect_success 'corrupt generation detected by verify-generations' '
	graph_file=.git/objects/info/commit-graph &&
	test_when_finished "chmod u+w \"$graph_file\" && \
		cp commit-graph-orig \"$graph_file\"" &&
	cp -f "$graph_file" commit-graph-orig &&
	chmod u+w "$graph_file" &&

	corrupt_generation_data "$graph_file" &&

	test-tool read-graph verify-generations >output &&
	grep "result: corrupt" output
'

test_expect_success 'auto-repair regenerates graph on corruption' '
	graph_file=.git/objects/info/commit-graph &&
	test_when_finished "rm -f commit-graph-orig" &&
	cp -f "$graph_file" commit-graph-orig &&
	chmod u+w "$graph_file" &&

	corrupt_generation_data "$graph_file" &&
	rm -f "$graph_file.gfix" &&

	git log --oneline -1 2>err &&
	grep "corrupt generation numbers" err &&
	grep "regenerating commit-graph" err &&

	test-tool read-graph verify-generations >output &&
	grep "result: ok" output &&
	test-tool read-graph >output &&
	grep -q "gfix" output
'

test_expect_success 'split graph: GFIX in all layers' '
	git init split &&
	(
		cd split &&
		test_commit base &&
		git commit-graph write --reachable --split &&
		test_commit tip &&
		git commit-graph write --reachable --split=no-merge &&

		test-tool read-graph >output &&
		grep -q "gfix" output
	)
'

test_expect_success 'split graph: sidecar files for each layer' '
	(
		cd split &&
		graphdir=.git/objects/info/commit-graphs &&

		for f in "$graphdir"/graph-*.graph; do
			chmod u+w "$f" &&
			clear_gfix_level "$f" || return 1
		done &&

		rm -f "$graphdir"/*.gfix &&

		GIT_TEST_FORCE_GENERATION_VERIFY=1 \
			git log --oneline -1 &&

		gfix_count=$(ls "$graphdir"/*.gfix 2>/dev/null | wc -l) &&
		graph_count=$(ls "$graphdir"/graph-*.graph 2>/dev/null | wc -l) &&
		test "$gfix_count" -eq "$graph_count"
	)
'

test_done
