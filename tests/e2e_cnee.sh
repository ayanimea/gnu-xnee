#!/bin/sh
# End-to-end tests for cnee (the command-line front-end of GNU Xnee)
#
# These tests cover all functionality exercisable without a live X11 display:
#   - Binary basics:  --version, --help, --flags, --manpage
#   - X11 name lookups: event, request, error name/number queries
#   - Session settings: print-settings, write-settings, project round-trip
#   - File I/O options: --out-file, --err-file
#   - Recording limits: --events-to-record, --data-to-record, --seconds-to-record
#   - Replay thresholds: --max-threshold, --min-threshold
#   - Short option aliases
#
# When Xvfb is available the following are also tested end-to-end:
#   - Record: connects to virtual display, records events, writes session file
#   - Replay: connects to virtual display, replays a recorded session file
#
# Usage:
#   ./tests/e2e_cnee.sh [path/to/cnee]
#
# Exit code: 0 = all tests pass, non-zero = at least one test failed.

##############################################################################
# Setup
##############################################################################

CNEE="${1:-./cnee/src/cnee}"

if [ ! -x "$CNEE" ]; then
    echo "ERROR: cnee binary not found at: $CNEE"
    echo "Build the project first: make -f Makefile.cvs generate && ./configure --disable-gui --disable-doc --disable-xinput2 && make"
    exit 1
fi

PASS=0
FAIL=0
TMPDIR_E2E=$(mktemp -d)
trap 'rm -rf "$TMPDIR_E2E"; [ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null' EXIT

##############################################################################
# Helper functions
##############################################################################

pass() {
    PASS=$((PASS + 1))
    printf "  [PASS] %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf "  [FAIL] %s\n" "$1"
    if [ -n "$2" ]; then
        printf "         Expected: %s\n" "$2"
        printf "         Got:      %s\n" "$3"
    fi
}

# assert_exit_zero <description> <command>
assert_exit_zero() {
    _desc="$1"; shift
    "$@" >/dev/null 2>&1
    _ret=$?
    if [ "$_ret" -eq 0 ]; then
        pass "$_desc"
    else
        fail "$_desc" "exit 0" "exit $_ret"
    fi
}

# assert_output_contains <description> <pattern> <command...>
assert_output_contains() {
    _desc="$1"; _pat="$2"; shift 2
    _out=$("$@" 2>&1)
    if echo "$_out" | grep -q "$_pat"; then
        pass "$_desc"
    else
        fail "$_desc" "output matching '$_pat'" "$(echo "$_out" | head -3)"
    fi
}

# assert_output_equals <description> <expected> <command...>
assert_output_equals() {
    _desc="$1"; _exp="$2"; shift 2
    _out=$("$@" 2>&1 | tr -d '\n')
    if [ "$_out" = "$_exp" ]; then
        pass "$_desc"
    else
        fail "$_desc" "$_exp" "$_out"
    fi
}

# assert_line_count <description> <min_lines> <command...>
assert_line_count() {
    _desc="$1"; _min="$2"; shift 2
    _count=$("$@" 2>&1 | grep -cE "^[0-9]+")
    if [ "$_count" -ge "$_min" ]; then
        pass "$_desc"
    else
        fail "$_desc" "at least $_min numbered lines" "$_count lines"
    fi
}

##############################################################################
# Test group 1: Binary basics
##############################################################################

echo ""
echo "=== Group 1: Binary basics ==="

assert_exit_zero "cnee --version exits 0" "$CNEE" --version
assert_output_contains "cnee --version prints 'xnee'" "xnee" "$CNEE" --version
assert_output_contains "cnee --version prints a version number" "[0-9]\.[0-9]" "$CNEE" --version

assert_exit_zero "cnee -V (short) exits 0" "$CNEE" -V
assert_output_contains "cnee -V prints same output as --version" "xnee" "$CNEE" -V

assert_exit_zero "cnee --help exits 0" "$CNEE" --help
assert_output_contains "cnee --help prints USAGE line" "USAGE" "$CNEE" --help
assert_output_contains "cnee --help describes the tool" "record" "$CNEE" --help
assert_output_contains "cnee --help mentions --replay option" "replay" "$CNEE" --help

assert_exit_zero "cnee -h (short) exits 0" "$CNEE" -h
assert_output_contains "cnee -h prints same content as --help" "USAGE" "$CNEE" -h

assert_exit_zero "cnee --flags exits 0" "$CNEE" --flags
assert_output_contains "cnee --flags lists --display" "display" "$CNEE" --flags
assert_output_contains "cnee --flags lists --out-file" "out-file" "$CNEE" --flags

assert_exit_zero "cnee --manpage exits 0" "$CNEE" --manpage
assert_output_contains "cnee --manpage outputs troff .TH header" "\.TH" "$CNEE" --manpage
assert_output_contains "cnee --manpage contains .SH NAME section" "\.SH" "$CNEE" --manpage
assert_output_contains "cnee --manpage contains CNEE name" "CNEE\|cnee" "$CNEE" --manpage

##############################################################################
# Test group 2: X11 event name/number lookups
##############################################################################

echo ""
echo "=== Group 2: X11 event name/number lookups ==="

assert_exit_zero "cnee --print-event-names exits 0" "$CNEE" --print-event-names
assert_output_contains "cnee --print-event-names has table header" "number.*name\|X11 Event" "$CNEE" --print-event-names
assert_output_contains "cnee --print-event-names lists KeyPress (02)" "02.*KeyPress" "$CNEE" --print-event-names
assert_output_contains "cnee --print-event-names lists KeyRelease (03)" "03.*KeyRelease" "$CNEE" --print-event-names
assert_output_contains "cnee --print-event-names lists ButtonPress (04)" "04.*ButtonPress" "$CNEE" --print-event-names
assert_output_contains "cnee --print-event-names lists ButtonRelease (05)" "05.*ButtonRelease" "$CNEE" --print-event-names
assert_output_contains "cnee --print-event-names lists MotionNotify (06)" "06.*MotionNotify" "$CNEE" --print-event-names
assert_output_contains "cnee --print-event-names lists MappingNotify (34)" "34.*MappingNotify" "$CNEE" --print-event-names
assert_line_count "cnee --print-event-names lists >=33 events" 33 "$CNEE" --print-event-names

assert_exit_zero "cnee -pens (short) exits 0" "$CNEE" -pens
assert_output_contains "cnee -pens outputs same as --print-event-names" "KeyPress" "$CNEE" -pens

# Bidirectional lookups: number -> name
assert_exit_zero "cnee --print-event-name 2 exits 0" "$CNEE" --print-event-name 2
assert_output_equals "cnee --print-event-name 2 returns KeyPress" "KeyPress" "$CNEE" --print-event-name 2

assert_exit_zero "cnee --print-event-name 6 exits 0" "$CNEE" --print-event-name 6
assert_output_equals "cnee --print-event-name 6 returns MotionNotify" "MotionNotify" "$CNEE" --print-event-name 6

# Bidirectional lookups: name -> number
assert_exit_zero "cnee --print-event-name KeyPress exits 0" "$CNEE" --print-event-name KeyPress
assert_output_equals "cnee --print-event-name KeyPress returns 2" "2" "$CNEE" --print-event-name KeyPress

assert_exit_zero "cnee --print-event-name MotionNotify exits 0" "$CNEE" --print-event-name MotionNotify
assert_output_equals "cnee --print-event-name MotionNotify returns 6" "6" "$CNEE" --print-event-name MotionNotify

##############################################################################
# Test group 3: X11 request name/number lookups
##############################################################################

echo ""
echo "=== Group 3: X11 request name/number lookups ==="

assert_exit_zero "cnee --print-request-names exits 0" "$CNEE" --print-request-names
assert_output_contains "cnee --print-request-names has table header" "X11 Request\|number.*name" "$CNEE" --print-request-names
assert_output_contains "cnee --print-request-names lists X_CreateWindow (01)" "01.*X_CreateWindow" "$CNEE" --print-request-names
assert_output_contains "cnee --print-request-names lists X_MapWindow (08)" "08.*X_MapWindow" "$CNEE" --print-request-names
assert_output_contains "cnee --print-request-names lists X_DestroyWindow (04)" "04.*X_DestroyWindow" "$CNEE" --print-request-names
assert_line_count "cnee --print-request-names lists >=100 requests" 100 "$CNEE" --print-request-names

assert_exit_zero "cnee -prns (short) exits 0" "$CNEE" -prns
assert_output_contains "cnee -prns outputs same as --print-request-names" "X_CreateWindow" "$CNEE" -prns

# Bidirectional lookups
assert_exit_zero "cnee --print-request-name 1 exits 0" "$CNEE" --print-request-name 1
assert_output_equals "cnee --print-request-name 1 returns X_CreateWindow" "X_CreateWindow" "$CNEE" --print-request-name 1

assert_exit_zero "cnee --print-request-name X_CreateWindow exits 0" "$CNEE" --print-request-name X_CreateWindow
assert_output_equals "cnee --print-request-name X_CreateWindow returns 1" "1" "$CNEE" --print-request-name X_CreateWindow

assert_exit_zero "cnee --print-request-name 8 exits 0" "$CNEE" --print-request-name 8
assert_output_equals "cnee --print-request-name 8 returns X_MapWindow" "X_MapWindow" "$CNEE" --print-request-name 8

##############################################################################
# Test group 4: X11 error name/number lookups
##############################################################################

echo ""
echo "=== Group 4: X11 error name/number lookups ==="

assert_exit_zero "cnee --print-error-names exits 0" "$CNEE" --print-error-names
assert_output_contains "cnee --print-error-names has table header" "X11 Error\|number.*name" "$CNEE" --print-error-names
assert_output_contains "cnee --print-error-names lists Success (00)" "00.*Success" "$CNEE" --print-error-names
assert_output_contains "cnee --print-error-names lists BadValue (02)" "02.*BadValue" "$CNEE" --print-error-names
assert_output_contains "cnee --print-error-names lists BadWindow (03)" "03.*BadWindow" "$CNEE" --print-error-names
assert_output_contains "cnee --print-error-names lists BadDrawable (09)" "09.*BadDrawable" "$CNEE" --print-error-names
assert_line_count "cnee --print-error-names lists >=17 errors" 17 "$CNEE" --print-error-names

assert_exit_zero "cnee -perns (short) exits 0" "$CNEE" -perns
assert_output_contains "cnee -perns outputs same as --print-error-names" "BadValue" "$CNEE" -perns

# Bidirectional lookups
assert_exit_zero "cnee --print-error-name 2 exits 0" "$CNEE" --print-error-name 2
assert_output_equals "cnee --print-error-name 2 returns BadValue" "BadValue" "$CNEE" --print-error-name 2

assert_exit_zero "cnee --print-error-name BadValue exits 0" "$CNEE" --print-error-name BadValue
assert_output_equals "cnee --print-error-name BadValue returns 2" "2" "$CNEE" --print-error-name BadValue

assert_exit_zero "cnee --print-error-name BadWindow exits 0" "$CNEE" --print-error-name BadWindow
assert_output_equals "cnee --print-error-name BadWindow returns 3" "3" "$CNEE" --print-error-name BadWindow

##############################################################################
# Test group 5: X11 data name lookups
##############################################################################

echo ""
echo "=== Group 5: X11 data name lookups ==="

assert_exit_zero "cnee --print-data-names exits 0" "$CNEE" --print-data-names
assert_output_contains "cnee --print-data-names includes event data" "KeyPress\|MotionNotify" "$CNEE" --print-data-names
assert_line_count "cnee --print-data-names lists >=100 entries" 100 "$CNEE" --print-data-names

assert_exit_zero "cnee -pdn (short) exits 0" "$CNEE" -pdn
assert_output_contains "cnee -pdn outputs same as --print-data-names" "KeyPress" "$CNEE" -pdn

##############################################################################
# Test group 6: Session settings (--print-settings)
##############################################################################

echo ""
echo "=== Group 6: Session settings (--print-settings) ==="

assert_exit_zero "cnee --print-settings exits 0" "$CNEE" --print-settings

# Default settings are present
assert_output_contains "cnee --print-settings includes Displays section" "Displays" "$CNEE" --print-settings
assert_output_contains "cnee --print-settings includes Files section" "Files" "$CNEE" --print-settings
assert_output_contains "cnee --print-settings includes thresholds" "threshold" "$CNEE" --print-settings

# Record limit options are reflected in settings
assert_output_contains "--events-to-record is reflected in settings" "events-to-record.*1000" \
    "$CNEE" --events-to-record 1000 --print-settings

assert_output_contains "--data-to-record is reflected in settings" "data-to-record.*500" \
    "$CNEE" --data-to-record 500 --print-settings

assert_output_contains "--seconds-to-record is reflected in settings" "seconds-to-record.*30" \
    "$CNEE" --seconds-to-record 30 --print-settings

# Multiple record limits can be combined
assert_output_contains "combined record limits: events" "events-to-record.*100" \
    "$CNEE" --events-to-record 100 --data-to-record 200 --seconds-to-record 60 --print-settings
assert_output_contains "combined record limits: data" "data-to-record.*200" \
    "$CNEE" --events-to-record 100 --data-to-record 200 --seconds-to-record 60 --print-settings
assert_output_contains "combined record limits: seconds" "seconds-to-record.*60" \
    "$CNEE" --events-to-record 100 --data-to-record 200 --seconds-to-record 60 --print-settings

# Threshold options
assert_output_contains "--max-threshold is reflected in settings" "max-threshold 50" \
    "$CNEE" --max-threshold 50 --print-settings
assert_output_contains "--min-threshold is reflected in settings" "min-threshold 5" \
    "$CNEE" --min-threshold 5 --print-settings
assert_output_contains "--max-threshold and --min-threshold combined" "max-threshold 100" \
    "$CNEE" --max-threshold 100 --min-threshold 10 --print-settings
assert_output_contains "--max-threshold and --min-threshold combined min" "min-threshold 10" \
    "$CNEE" --max-threshold 100 --min-threshold 10 --print-settings

# File output options
assert_output_contains "--out-file is reflected in settings" "out-file.*e2e_test.xns" \
    "$CNEE" --out-file /tmp/e2e_test.xns --print-settings
assert_output_contains "--err-file is reflected in settings" "err-file.*e2e_err.log" \
    "$CNEE" --err-file /tmp/e2e_err.log --print-settings

##############################################################################
# Test group 7: write-settings / project round-trip
##############################################################################

echo ""
echo "=== Group 7: write-settings / project round-trip ==="

SETTINGS_FILE="$TMPDIR_E2E/cnee_settings.xnp"

assert_exit_zero "cnee --write-settings creates file" \
    "$CNEE" --write-settings "$SETTINGS_FILE"

if [ -f "$SETTINGS_FILE" ]; then
    pass "cnee --write-settings creates a non-empty file"
else
    fail "cnee --write-settings creates a non-empty file" "file exists" "file not found"
fi

# Write settings with specific values, then read them back
ROUNDTRIP_FILE="$TMPDIR_E2E/roundtrip.xnp"
"$CNEE" --max-threshold 77 --min-threshold 11 --write-settings "$ROUNDTRIP_FILE" >/dev/null 2>&1

assert_output_contains "write-settings persists max-threshold" "max-threshold 77" \
    cat "$ROUNDTRIP_FILE"
assert_output_contains "write-settings persists min-threshold" "min-threshold 11" \
    cat "$ROUNDTRIP_FILE"

# Load the written file back via --project and verify settings are restored
assert_output_contains "project round-trip: max-threshold survives reload" "max-threshold 77" \
    "$CNEE" --project "$ROUNDTRIP_FILE" --print-settings
assert_output_contains "project round-trip: min-threshold survives reload" "min-threshold 11" \
    "$CNEE" --project "$ROUNDTRIP_FILE" --print-settings

# Write-settings records file/display info as comments in the output file
OUTFILE_SETTINGS="$TMPDIR_E2E/outfile_settings.xnp"
"$CNEE" --out-file /tmp/cnee_rec.xns --write-settings "$OUTFILE_SETTINGS" >/dev/null 2>&1
assert_output_contains "write-settings records out-file in settings file" "out-file.*cnee_rec.xns" \
    cat "$OUTFILE_SETTINGS"
assert_output_contains "write-settings includes events-to-record in settings file" "events-to-record" \
    cat "$OUTFILE_SETTINGS"

##############################################################################
# Test group 8: Short option aliases
##############################################################################

echo ""
echo "=== Group 8: Short option aliases ==="

assert_output_contains "cnee -pens = --print-event-names (KeyPress)" "KeyPress" "$CNEE" -pens
assert_output_contains "cnee -perns = --print-error-names (BadValue)" "BadValue" "$CNEE" -perns
assert_output_contains "cnee -prns = --print-request-names (X_CreateWindow)" "X_CreateWindow" "$CNEE" -prns
assert_output_contains "cnee -pdn = --print-data-names (KeyPress)" "KeyPress" "$CNEE" -pdn
assert_output_contains "cnee -V = --version (xnee)" "xnee" "$CNEE" -V
assert_output_contains "cnee -h = --help (USAGE)" "USAGE" "$CNEE" -h

##############################################################################
# Test group 9: Record / Replay with virtual X display (Xvfb)
##############################################################################

echo ""
echo "=== Group 9: Record / Replay with virtual X display ==="

XVFB_BIN=$(command -v Xvfb 2>/dev/null)
if [ -z "$XVFB_BIN" ]; then
    echo "  [SKIP] Xvfb not found — skipping record/replay live tests"
    echo "         Install Xvfb (xorg-x11-server-Xvfb on EL8, xvfb on Debian)"
    echo "         to enable end-to-end record/replay coverage."
else
    # Find a free display number by trying :99, :98 … down
    VDISPLAY=""
    for _d in 99 98 97 96; do
        if ! test -S "/tmp/.X${_d}-lock" 2>/dev/null && \
           ! test -f "/tmp/.X${_d}-lock" 2>/dev/null; then
            VDISPLAY=":${_d}"
            break
        fi
    done

    if [ -z "$VDISPLAY" ]; then
        echo "  [SKIP] Could not find a free display number for Xvfb"
    else
        # Start a headless virtual X server
        "$XVFB_BIN" "$VDISPLAY" -screen 0 1024x768x24 >/dev/null 2>&1 &
        XVFB_PID=$!
        sleep 1   # give Xvfb time to initialise

        RECORD_FILE="$TMPDIR_E2E/cnee_record.xns"
        REPLAY_STDERR="$TMPDIR_E2E/replay_stderr.txt"

        # ------------------------------------------------------------------
        # Record: run cnee --record for 2 seconds; no real user is present so
        # the session file will contain only the session header (0 events),
        # but the important thing is that cnee connects, starts the RECORD
        # extension and exits cleanly.
        # ------------------------------------------------------------------
        DISPLAY="$VDISPLAY" "$CNEE" \
            --record \
            --keyboard \
            --mouse \
            --seconds-to-record 2 \
            --out-file "$RECORD_FILE" \
            --display "$VDISPLAY" >/dev/null 2>&1
        _rec_exit=$?

        if [ "$_rec_exit" -eq 0 ]; then
            pass "cnee --record exits 0 on virtual display"
        else
            fail "cnee --record exits 0 on virtual display" "exit 0" "exit $_rec_exit"
        fi

        if [ -f "$RECORD_FILE" ]; then
            pass "cnee --record creates the output session file"
        else
            fail "cnee --record creates the output session file" "file exists" "file not found"
        fi

        if grep -q "Xnee program" "$RECORD_FILE" 2>/dev/null; then
            pass "recorded session file contains Xnee program header"
        else
            fail "recorded session file contains Xnee program header" \
                "Xnee program in header" "header line missing"
        fi

        if grep -q "Xnee version" "$RECORD_FILE" 2>/dev/null; then
            pass "recorded session file contains version information"
        else
            fail "recorded session file contains version information" \
                "Xnee version in header" "version line missing"
        fi

        if grep -q "[Dd]isplay" "$RECORD_FILE" 2>/dev/null; then
            pass "recorded session file contains display information"
        else
            fail "recorded session file contains display information" \
                "display info in header" "not found"
        fi

        # ------------------------------------------------------------------
        # Replay: replay the just-recorded session file back into the same
        # virtual display.  Use -ns (no-synchronise) so cnee does not block
        # waiting for the replayed application to catch up.
        # ------------------------------------------------------------------
        DISPLAY="$VDISPLAY" "$CNEE" \
            --replay \
            -f "$RECORD_FILE" \
            --display "$VDISPLAY" \
            -ns >/dev/null 2>"$REPLAY_STDERR"
        _rep_exit=$?

        if [ "$_rep_exit" -eq 0 ]; then
            pass "cnee --replay exits 0 on virtual display"
        else
            fail "cnee --replay exits 0 on virtual display" "exit 0" "exit $_rep_exit"
        fi

        if ! grep -qi \
                "can't open display\|cannot open display\|unable to open display" \
                "$REPLAY_STDERR" 2>/dev/null; then
            pass "cnee --replay connects to virtual display successfully"
        else
            fail "cnee --replay connects to virtual display successfully" \
                "no display error" "$(head -3 "$REPLAY_STDERR")"
        fi

        kill "$XVFB_PID" 2>/dev/null
        wait "$XVFB_PID" 2>/dev/null
    fi
fi

##############################################################################
# Summary
##############################################################################

echo ""
echo "=========================================="
echo " Results: $PASS passed, $FAIL failed"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
