#!/bin/bash
# Two real game processes play with each other. Run from the project folder.
#
# On the live database, on a throwaway branch of it that is deleted afterwards.
# This only works while the database rules are open, as these bots have no account:
#   GODOT=/path/to/godot bash tests/run_net_test.sh
#
# With real accounts and firebase/database.rules.json, on the local emulators:
#   npx firebase emulators:exec --project demo-gag --only auth,database \
#     "GG_EMULATOR=1 GODOT=/path/to/godot bash tests/run_net_test.sh"
GODOT="${GODOT:-godot}"
DB="https://virus-roller-default-rtdb.firebaseio.com"
OUT="$(mktemp -d)"
FAILED=0
if [ -z "$GG_EMULATOR" ]; then
	export GG_NET_ROOT="gag_test_$(date +%s)"
fi

play() { # first bot, second bot, code
	GG_NET_BOT=$1 GG_NET_UID="${1}_$$" GG_NET_CODE=$3 "$GODOT" --headless --path . > "$OUT/$1.log" 2>&1 &
	local a=$!
	GG_NET_BOT=$2 GG_NET_UID="${2}_$$" GG_NET_CODE=$3 "$GODOT" --headless --path . > "$OUT/$2.log" 2>&1 &
	local b=$!
	wait $a || FAILED=1
	wait $b || FAILED=1
	grep -hE '^\[|SCRIPT ERROR|^ERROR: .*(res://|Invalid)|at: .*res://' "$OUT/$1.log" "$OUT/$2.log"
}

echo "=== Garden Club"
play host guest TESTAB
echo "=== Open Village"
play villager_a villager_b s1
if [ -n "$GG_EMULATOR" ]; then
	echo "=== Friends"
	play friend_a friend_b none
else
	echo "=== Left behind in the database (should be small)"
	curl -s "$DB/$GG_NET_ROOT.json" | wc -c
	curl -s -o /dev/null -X DELETE "$DB/$GG_NET_ROOT.json?print=silent"
fi
echo "logs: $OUT"
exit $FAILED
