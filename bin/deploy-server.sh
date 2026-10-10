#!/usr/bin/env bash
# server-build/ 의 게임 서버를 배포 서버에 올리고 재시작합니다. 빌드는 하지 않습니다.
#
#   사용법: ./deploy-server
#     먼저 ./build-server 로 빌드하세요.
#     예)  ./build-server && ./deploy-server
#
# 빌드는 bin/build-server.sh 의 일입니다. 여기는 올리고, 갈아 끼우고, 확인하는 일만 합니다.
# 대신 빌드 뒤에 소스가 바뀌었으면 경고합니다. 예전 빌드를 모르고 올리는 걸 막으려는 것입니다.
# 접속 정보는 .deploy-server.env 에 둡니다 (.gitignore 대상, .deploy-server.env.example 을 복사).
# 서버 쪽 준비(Caddy, systemd 유닛)는 docs/deployment.md 를 보세요.
#
# [중요] 실행 중인 바이너리 위에 scp 로 덮어쓰면 Linux 는 "Text file busy" 로 거부합니다.
# 그래서 .new 로 올린 뒤 mv 로 바꿔치기합니다. rename 은 실행 중이어도 됩니다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BINARY_NAME="crazy-arcade-server.x86_64"
out_path="$ROOT/server-build/$BINARY_NAME"

while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help)
			# -E (ERE) 필요: BSD sed 는 BRE 의 \? 를 지원하지 않아 조용히 실패합니다.
			sed -n '2,6p' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//'
			exit 0
			;;
		*)
			echo "알 수 없는 옵션: $1" >&2
			echo "사용법: ./deploy-server   (빌드는 ./build-server)" >&2
			exit 2
			;;
	esac
done

if [[ ! -s "$out_path" ]]; then
	echo "server-build/$BINARY_NAME 이 없습니다. 먼저 ./build-server 를 하세요." >&2
	exit 1
fi

# 빌드 뒤에 바뀐 소스가 있으면 경고만 합니다. 서버와 무관한 파일(예: 클라이언트 뷰)일 수도 있어서
# 막지는 않습니다. 판단은 사람이 합니다.
newer="$(cd "$ROOT" && find src scenes assets project.godot -newer "$out_path" -type f \
	-not -name '*.import' -not -name '*.uid' 2>/dev/null | head -5)"
built_at="$(date -r "$out_path" '+%Y-%m-%d %H:%M')"
echo "올릴 빌드: server-build/$BINARY_NAME ($built_at 빌드)" >&2
if [[ -n "$newer" ]]; then
	echo "" >&2
	echo "경고: 빌드 뒤에 바뀐 파일이 있습니다. 이 변경은 올라가지 않습니다." >&2
	echo "$newer" | sed 's/^/  /' >&2
	echo "  반영하려면 Ctrl+C 후 ./build-server 를 먼저 하세요. 계속하려면 Enter." >&2
	read -r _
fi

env_file="$ROOT/.deploy-server.env"
if [[ ! -f "$env_file" ]]; then
	echo ".deploy-server.env 가 없습니다. 예시를 복사해서 값을 채우세요 (.gitignore 대상):" >&2
	echo "  cp .deploy-server.env.example .deploy-server.env" >&2
	exit 1
fi
# shellcheck source=/dev/null
source "$env_file"
: "${DEPLOY_HOST:?.deploy-server.env 에 DEPLOY_HOST 가 없습니다}"
DEPLOY_USER="${DEPLOY_USER:-ubuntu}"
DEPLOY_KEY="${DEPLOY_KEY:-$HOME/.ssh/oracle.key}"
DEPLOY_KEY="${DEPLOY_KEY/#\~/$HOME}"
REMOTE_DIR="/home/$DEPLOY_USER/crazy-arcade"
SERVICE="crazy-arcade"

# IPQoS=none: macOS 의 ssh 는 큰 파일을 올리다 "ssh_packet_write_poll: ... Result too large /
# lost connection" 으로 끊긴 적이 있습니다(75MB 중 16MB에서). QoS 표시를 끄면 끝까지 갑니다.
ssh_opts=(-i "$DEPLOY_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o IPQoS=none)
remote="$DEPLOY_USER@$DEPLOY_HOST"

echo "업로드 중 → $remote ..." >&2
# .new 를 먼저 지웁니다. 끊긴 업로드의 sftp-server 가 서버에 살아남아 예전 .new 를 쓰기 모드로
# 붙잡고 있으면, 같은 파일에 다시 올려 갈아 끼운 바이너리가 "Text file busy"(203/EXEC)로 안 뜹니다.
# 지우고 올리면 새 파일이 생기므로 남은 프로세스와 엮이지 않습니다.
ssh "${ssh_opts[@]}" "$remote" "mkdir -p '$REMOTE_DIR' && rm -f '$REMOTE_DIR/$BINARY_NAME.new'"
scp "${ssh_opts[@]}" -q "$out_path" "$remote:$REMOTE_DIR/$BINARY_NAME.new"

# 끊긴 업로드는 반쪽짜리 파일을 남깁니다. 그걸로 갈아 끼우면 서버가 못 뜹니다. 해시로 확인합니다.
local_hash="$(shasum -a 256 "$out_path" | cut -d' ' -f1)"
remote_hash="$(ssh "${ssh_opts[@]}" "$remote" "sha256sum '$REMOTE_DIR/$BINARY_NAME.new'" | cut -d' ' -f1)"
if [[ "$local_hash" != "$remote_hash" ]]; then
	echo "업로드한 파일이 로컬과 다릅니다 (전송이 중간에 끊겼을 수 있습니다). 재시작하지 않습니다." >&2
	echo "  다시 ./deploy-server 를 하세요. 서버는 이전 버전으로 계속 돌고 있습니다." >&2
	exit 1
fi

echo "재시작 중..." >&2
ssh "${ssh_opts[@]}" "$remote" "
	set -e
	chmod +x '$REMOTE_DIR/$BINARY_NAME.new'
	mv -f '$REMOTE_DIR/$BINARY_NAME.new' '$REMOTE_DIR/$BINARY_NAME'
	sudo systemctl restart '$SERVICE'
"

# systemd 가 active 라고 해도 Caddy 를 거쳐 WebSocket 이 열리는지는 따로 봐야 합니다.
# 101 이 오면 TLS → Caddy → 게임 서버까지 이어진 것입니다.
echo "확인 중 (wss://$DEPLOY_HOST)..." >&2
code=""
for _ in 1 2 3 4 5; do
	sleep 2
	code="$(curl -s -o /dev/null -w '%{http_code}' --http1.1 --max-time 4 \
		-H "Connection: Upgrade" -H "Upgrade: websocket" \
		-H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
		"https://$DEPLOY_HOST" || true)"
	if [[ "$code" == "101" ]]; then
		echo ""
		echo "배포 완료: wss://$DEPLOY_HOST 응답 101"
		echo "로그 보기:  ssh -i $DEPLOY_KEY $remote 'journalctl -u $SERVICE -f'"
		exit 0
	fi
done

echo "" >&2
echo "배포는 했지만 WebSocket 응답이 101 이 아닙니다 (마지막: $code)." >&2
ssh "${ssh_opts[@]}" "$remote" "systemctl status '$SERVICE' --no-pager -n 20" >&2 || true
exit 1
