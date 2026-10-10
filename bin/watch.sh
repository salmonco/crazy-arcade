#!/usr/bin/env bash
# 파일이 바뀔 때마다 테스트를 자동으로 다시 돌립니다. TDD 루프용.
#
#   bin/watch.sh                                # test/ 전체를 감시하며 반복 실행
#   bin/watch.sh test/core                      # 특정 디렉터리만 실행 (감시는 전체)
#   bin/watch.sh test/core/tick_clock_test.gd   # 한 파일만 — 레드-그린 루프에서 가장 빠름
#
# Ctrl-C로 종료.
#
# 외부 의존성이 없습니다(fswatch/entr 불필요). mtime 폴링으로 감시합니다 —
# 감시 대상이 수십 개 파일뿐이라 폴링 비용은 무시할 수준입니다.
#
# 전역 클래스 캐시(--import) 갱신은 bin/test.sh 가 알아서 판단합니다.
# 여기서 따로 하지 않습니다 — 판단 지점이 둘이면 언젠가 어긋납니다.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 보통은 bin/test.sh -w 로 들어옵니다. 직접 불러도 됩니다.
# 인자: [--gui] [경로]
GUI=false
TARGET="test"
while [[ $# -gt 0 ]]; do
	case "$1" in
		-g|--gui) GUI=true; shift ;;
		*) TARGET="$1"; shift ;;
	esac
done

WATCH_DIRS=(src test scenes)
POLL_SECONDS=0.5

# stat 포맷은 BSD(macOS)와 GNU(Linux)가 다릅니다.
if stat -f %m . >/dev/null 2>&1; then
	STAT_ARGS=(-f '%m %N')
else
	STAT_ARGS=(-c '%Y %n')
fi

# 감시 대상 파일들의 (수정시각, 경로) 스냅샷.
mtime_snapshot() {
	find "${WATCH_DIRS[@]}" project.godot -type f \
		\( -name '*.gd' -o -name '*.tscn' -o -name 'project.godot' \) -print0 2>/dev/null \
		| xargs -0 stat "${STAT_ARGS[@]}" 2>/dev/null | sort
}

run_tests() {
	local log
	log="$(mktemp)"

	printf '\033[2J\033[3J\033[H'  # 화면 + 스크롤백 클리어. 3J 가 없으면 지난 실행이 위로 밀려 남습니다.
	printf '\033[1m watch: %s\033[0m   \033[90m(%s · Ctrl-C로 종료)\033[0m\n\n' \
		"$TARGET" "$(date +%H:%M:%S)"

	# bash 3.2 + set -u 에서 빈 배열 전개가 죽으므로 분기해서 부릅니다.
	local code
	if [[ "$GUI" == true ]]; then
		bin/test.sh --gui "$TARGET" >"$log" 2>&1
	else
		bin/test.sh "$TARGET" >"$log" 2>&1
	fi
	code=$?

	# ANSI 코드를 벗기고 결과 줄만 추립니다.
	# 실패 리포트는 문구를 열거하지 않고 'Report:' 부터 빈 줄까지 블록째 남깁니다.
	# 실패 위치는 '파일:줄' 로 고쳐 찍습니다. 터미널에서 눌러 바로 열 수 있습니다.
	sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log" \
		| awk '
			/Run Test Suite:/ {
				suite = $0
				sub(/.*Run Test Suite: */, "", suite)
				sub(/^res:\/\//, "", suite)
				if (suites++) printf "\n"
				printf "\033[1m%s\033[0m\n", suite
				next
			}
			/ > .* (PASSED|FAILED) [0-9]+ms$/ {
				name = $0
				sub(/^.* > /, "", name)
				sub(/ (PASSED|FAILED) [0-9]+ms$/, "", name)
				sub(/^test_/, "", name)
				if ($0 ~ / FAILED /) {
					located = 0
					fails[++n] = suite "  " name
					printf "  \033[31m✗ FAILED\033[0m %s\n", name
				} else {
					printf "  \033[32m✓\033[0m %s\n", name
				}
				next
			}
			/Report:/ { in_report = 1; next }
			in_report && /^[[:space:]]*$/ { in_report = 0; next }
			in_report {
				if (n > 0 && !located && match($0, /line [0-9]+:/)) {
					located = 1
					where = suite ":" substr($0, RSTART + 5, RLENGTH - 6)
					fails[n] = where "  " name
					sub(/line [0-9]+:/, where, $0)
				}
				print
				next
			}
			/^[[:space:]]+Parse Error/ { print; next }
			/^[[:space:]]*at res:\/\// { sub(/res:\/\//, ""); print; next }
			/캐시 갱신|Abnormal exit|Overall Summary/ { print }
			END {
				if (n > 0) {
					printf "\n\033[31m 실패 %d개\033[0m\n", n
					for (i = 1; i <= n; i++) printf "   %s\n", fails[i]
				}
			}
		'

	echo
	if [[ $code -eq 0 ]]; then
		printf '\033[32m ✓ 통과\033[0m\n'
	else
		printf '\033[31m ✗ 실패 (exit %d)\033[0m\n' "$code"
	fi

	rm -f "$log"
}

printf '\033[90m감시 중: %s\033[0m\n' "${WATCH_DIRS[*]}"

prev_mtimes="$(mtime_snapshot)"
run_tests

while true; do
	sleep "$POLL_SECONDS"

	current_mtimes="$(mtime_snapshot)"
	[[ "$current_mtimes" == "$prev_mtimes" ]] && continue

	# 에디터가 파일을 여러 번에 나눠 쓰는 경우가 있어 잠깐 가라앉기를 기다립니다.
	sleep 0.2
	run_tests
	# 테스트 실행이 .uid 등을 만들 수 있으므로 실행 "후"의 상태를 기준으로 삼습니다.
	prev_mtimes="$(mtime_snapshot)"
done
