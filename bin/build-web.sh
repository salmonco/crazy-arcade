#!/usr/bin/env bash
# 웹 빌드를 만듭니다.
#
#   사용법: ./build-web [-d|--debug] [-s|--skip-tests] [출력 경로]
#     경로 없으면 web-build/index.html 로 내보냅니다.  (./build-web 는 이 스크립트의 단축 실행기)
#     -d: 디버그 빌드 (에러와 스택 트레이스가 브라우저 콘솔에 나옵니다).
#     -s: 테스트를 건너뜁니다.
#     예)  ./build-web
#          ./build-web -d
#          ./build-web dist/index.html
#
# [중요] 내보내기 전에 ./t 를 돌립니다. 느려서가 아니라, 그러지 않으면 깨진 빌드를
# 알아챌 방법이 없기 때문입니다. `--export-release` 는 스크립트를 컴파일하지 않습니다.
# 문법이 깨진 .gd 도 .gdc 로 그대로 패킹하고 종료 코드 0 으로 끝냅니다. `--import` 도
# 마찬가지입니다. 둘 다 초록불을 주고, 브라우저를 열어야 비로소 죽습니다.
# 실제로 걸러내는 건 테스트뿐입니다. -s 로 끌 수 있지만 그때는 초록불이 없는 겁니다.
#
# 결과물은 file:// 로 열리지 않습니다. Godot 이 .pck 를 fetch 로 읽는데 file:// 은
# CORS 에 막힙니다. HTTP 로 띄워야 하며, 그 방법을 마지막에 찍어줍니다.
#
# 실패 시 non-zero 로 종료하므로 CI 에 그대로 물릴 수 있습니다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# godot_bin 을 설정합니다 (bin/test.sh, bin/run.sh 와 공유).
source "$ROOT/bin/_godot.sh"

PRESET="Web"
target="web-build/index.html"
mode="--export-release"
skip_tests=false

while [[ $# -gt 0 ]]; do
	case "$1" in
		-d|--debug)      mode="--export-debug"; shift ;;
		-s|--skip-tests) skip_tests=true;       shift ;;
		-h|--help)
			# -E (ERE) 필요: BSD sed 는 BRE 의 \? 를 지원하지 않아 조용히 실패합니다.
			sed -n '2,10p' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//'
			exit 0
			;;
		-*)
			echo "알 수 없는 옵션: $1" >&2
			echo "사용법: ./build-web [-d|--debug] [-s|--skip-tests] [출력 경로]" >&2
			exit 2
			;;
		*) target="$1"; shift ;;
	esac
done

# export_presets.cfg 는 .gitignore 대상입니다. 클론 직후에는 없어서, 그대로 두면
# Godot 이 "Unknown export preset" 한 줄만 남기고 끝납니다. 무엇을 해야 하는지 알려줍니다.
if [[ ! -f "$ROOT/export_presets.cfg" ]]; then
	echo "export_presets.cfg 가 없습니다. (.gitignore 대상이라 클론에는 안 따라옵니다)" >&2
	echo "  ./run -e 로 에디터를 열고 프로젝트 > 내보내기 에서 '$PRESET' 프리셋을 추가하세요." >&2
	exit 1
fi
if ! grep -q "^name=\"$PRESET\"" "$ROOT/export_presets.cfg"; then
	echo "export_presets.cfg 에 '$PRESET' 프리셋이 없습니다." >&2
	echo "  ./run -e 로 에디터를 열고 프로젝트 > 내보내기 에서 추가하세요." >&2
	exit 1
fi

if [[ "$skip_tests" == true ]]; then
	# ./t 를 건너뛰면 전역 클래스 캐시를 갱신해줄 사람이 없습니다. 여기서 직접 합니다.
	# 이 표(.godot/global_script_class_cache.cfg)가 낡으면 class_name 이 해석되지 않습니다.
	echo "테스트 건너뜀. 전역 클래스 캐시 갱신 중 (~4초)..." >&2
	"$godot_bin" --headless --path "$ROOT" --import >/dev/null 2>&1
else
	echo "테스트 실행 중..." >&2
	if ! "$ROOT/bin/test.sh" >/dev/null 2>&1; then
		echo "테스트가 실패했습니다. 빌드하지 않습니다." >&2
		echo "  ./t 로 무엇이 깨졌는지 보세요.  (급하면 ./build-web -s)" >&2
		exit 1
	fi
fi

# 상대 경로는 프로젝트 루트 기준으로 봅니다. 어디서 부르든 ./build-web dist/index.html 이
# 같은 자리를 가리키게 하려는 것이고, 절대 경로는 그대로 씁니다.
if [[ "$target" == /* ]]; then
	out_path="$target"
else
	out_path="$ROOT/$target"
fi
mkdir -p "$(dirname "$out_path")"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

set +e
"$godot_bin" --headless --path "$ROOT" "$mode" "$PRESET" "$out_path" 2>&1 | tee "$log"
status="${PIPESTATUS[0]}"
set -e

# 내보내기 자체가 실패하는 경우(템플릿 없음 등)는 종료 코드로 오지 않을 때가 있어 로그도 봅니다.
# "N RIDs ... were leaked at exit" 는 헤드리스 종료 때 늘 나오는 잡음이라 걸러야 하므로,
# 통째로 "ERROR" 를 찾지 않고 실제 실패 문구만 집습니다.
if grep -qE "No export template|Failed to export|Template file not found" "$log"; then
	echo "" >&2
	echo "빌드 실패: 내보내기 템플릿이 없습니다. 에디터 > 편집기 > 내보내기 템플릿 관리에서 받으세요." >&2
	exit 1
fi
if [[ "$status" -ne 0 ]]; then
	echo "" >&2
	echo "빌드 실패: Godot 이 $status 로 종료했습니다." >&2
	exit "$status"
fi

out_dir="$(cd "$(dirname "$out_path")" && pwd)"
base="$(basename "$out_path" .html)"
for f in "$base.html" "$base.js" "$base.wasm" "$base.pck"; do
	if [[ ! -s "$out_dir/$f" ]]; then
		echo "빌드 실패: $f 가 없거나 비어 있습니다." >&2
		exit 1
	fi
done

echo ""
echo "빌드 완료: $target"
du -h "$out_dir/$base.pck" "$out_dir/$base.wasm"
echo ""
echo "열어보기:  (cd $(dirname "$target") && python3 -m http.server 8000)  →  http://localhost:8000/$base.html"
