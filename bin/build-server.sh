#!/usr/bin/env bash
# 게임 서버(Linux x86_64, headless) 빌드를 만듭니다.
#
#   사용법: ./build-server [-s|--skip-tests]
#     server-build/crazy-arcade-server.x86_64 로 내보냅니다.  (./build-server 는 이 스크립트의 단축 실행기)
#     -s: 테스트를 건너뜁니다.
#     예)  ./build-server
#
# 'Linux Server' 내보내기 프리셋이 필요합니다. 만드는 법은 docs/deployment.md 에 있습니다.
#
# [중요] 내보내기 전에 ./t 를 돌리는 이유는 bin/build-web.sh 와 같습니다. `--export-release` 는
# 문법이 깨진 .gd 도 그대로 패킹하고 0 으로 끝냅니다. 걸러내는 건 테스트뿐입니다.
#
# 실패 시 non-zero 로 종료하므로 ./build-server && ./deploy-server 로 이어 쓸 수 있습니다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# godot_bin 을 설정합니다 (bin/test.sh, bin/run.sh, bin/build-web.sh 와 공유).
source "$ROOT/bin/_godot.sh"

PRESET="Linux Server"
out_path="$ROOT/server-build/crazy-arcade-server.x86_64"
skip_tests=false

while [[ $# -gt 0 ]]; do
	case "$1" in
		-s|--skip-tests) skip_tests=true; shift ;;
		-h|--help)
			# -E (ERE) 필요: BSD sed 는 BRE 의 \? 를 지원하지 않아 조용히 실패합니다.
			sed -n '2,7p' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//'
			exit 0
			;;
		*)
			echo "알 수 없는 옵션: $1" >&2
			echo "사용법: ./build-server [-s|--skip-tests]" >&2
			exit 2
			;;
	esac
done

if [[ ! -f "$ROOT/export_presets.cfg" ]] || ! grep -q "^name=\"$PRESET\"" "$ROOT/export_presets.cfg"; then
	echo "export_presets.cfg 에 '$PRESET' 프리셋이 없습니다. (.gitignore 대상이라 클론에는 안 따라옵니다)" >&2
	echo "  만드는 법은 docs/deployment.md 의 '프로젝트 쪽 설정'을 보세요." >&2
	exit 1
fi

if [[ "$skip_tests" == true ]]; then
	# ./t 를 건너뛰면 전역 클래스 캐시를 갱신해줄 사람이 없습니다. 여기서 직접 합니다.
	echo "테스트 건너뜀. 전역 클래스 캐시 갱신 중 (~4초)..." >&2
	"$godot_bin" --headless --path "$ROOT" --import >/dev/null 2>&1
else
	echo "테스트 실행 중..." >&2
	if ! "$ROOT/bin/test.sh" >/dev/null 2>&1; then
		echo "테스트가 실패했습니다. 빌드하지 않습니다." >&2
		echo "  ./t 로 무엇이 깨졌는지 보세요.  (급하면 ./build-server -s)" >&2
		exit 1
	fi
fi

mkdir -p "$(dirname "$out_path")"
rm -f "$out_path"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

echo "서버 빌드 중..." >&2
set +e
"$godot_bin" --headless --path "$ROOT" --export-release "$PRESET" "$out_path" >"$log" 2>&1
status=$?
set -e
# 내보내기 실패가 종료 코드로 오지 않을 때가 있어 로그도 봅니다 (bin/build-web.sh 와 같은 이유).
if [[ "$status" -ne 0 ]] || grep -qE "No export template|Failed to export|Template file not found" "$log"; then
	cat "$log" >&2
	echo "" >&2
	echo "빌드 실패. Linux 내보내기 템플릿이 있는지 확인하세요 (편집기 > 내보내기 템플릿 관리)." >&2
	exit 1
fi

if [[ ! -s "$out_path" ]]; then
	echo "빌드 실패: $out_path 가 없거나 비어 있습니다." >&2
	exit 1
fi
# 아키텍처가 틀리면 서버에서 "exec format error" 로만 죽습니다. 여기서 잡습니다.
if ! file "$out_path" | grep -q "ELF 64-bit.*x86-64"; then
	echo "빌드 실패: Linux x86_64 실행 파일이 아닙니다: $(file -b "$out_path")" >&2
	echo "  'Linux Server' 프리셋의 아키텍처를 확인하세요." >&2
	exit 1
fi

echo ""
echo "빌드 완료: server-build/$(basename "$out_path")"
du -h "$out_path"
