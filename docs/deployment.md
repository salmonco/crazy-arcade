# 배포 가이드

멀티플레이어 서버와 웹 클라이언트를 어떻게 배포했는지, 서버를 처음부터 다시 만들려면 무엇을 하는지 적습니다.
**서버 설정(Caddyfile, systemd 유닛)은 서버 안에만 있습니다.** 인스턴스가 사라지면 이 문서가 유일한 사본입니다.

## 구성

```
브라우저(Vercel) ─wss://─▶ <게임 서버 도메인>:443 ─▶ Caddy(TLS) ─ws://─▶ localhost:8080 Godot 서버(systemd)
```

| 구성 요소 | 어디에 | 비고 |
|---|---|---|
| 웹 클라이언트 | Vercel | `./build-web` 결과물(`web-build/`) |
| 게임 서버 | Oracle Cloud Always Free, 홈 리전 **Japan Central (Osaka)** | `VM.Standard.E2.1.Micro` (x86_64, 1/8 OCPU, 1GB) |
| 도메인 | 개인 도메인의 서브도메인 (`.deploy-server.env`의 `DEPLOY_HOST`) | A 레코드 → 서버 공용 IP |
| TLS / 프록시 | Caddy | Let's Encrypt 인증서 자동 발급·갱신 |
| 상시 실행 | systemd 유닛 `crazy-arcade` | `--headless --max-fps 60`, 죽으면 3초 뒤 재시작 |

DB는 없습니다. 로비·방·캐릭터는 전부 서버 메모리에 있고, 재시작하면 사라져도 되는 상태입니다.

## 프로젝트 쪽 설정 (저장소에 있음)

- **`application/run/main_scene.dedicated_server`** = `res://scenes/server.tscn`
  서버용으로 내보낸 빌드는 클라이언트(`game.tscn`)가 아니라 서버 씬으로 시작합니다.
- **`network/server_url`** = `ws://localhost:8080`, **`network/server_url.web`** = `wss://<게임 서버 도메인>`
  웹 빌드만 배포 서버로 접속합니다. 로컬에서 띄운 웹 빌드도 배포 서버로 붙는다는 점에 주의하세요.
- 내보내기 프리셋 **`Linux Server`**: 플랫폼 Linux, 아키텍처 x86_64, PCK 임베드, 리소스 탭의 내보내기 모드는 "Export as dedicated server", 경로는 `server-build/`.
  `export_presets.cfg`는 `.gitignore` 대상이라 클론에는 없습니다. 위 값대로 다시 만드세요.
  Linux 내보내기 템플릿이 필요합니다(편집기 → 내보내기 템플릿 관리에서 Linux와 Web 체크).

## 함정 (실제로 겪은 것들)

- **`ProjectSettings.get_setting()`은 기능 태그 오버라이드(`.web` 등)를 무시합니다.** `get_setting_with_override()`를 써야 합니다.
  `get_setting`으로 짠 동안 테스트는 전부 초록이었고, 웹 빌드는 `ws://localhost:8080`으로 접속하고 있었습니다.
  엔진이 직접 읽는 설정(`main_scene` 등)은 오버라이드가 적용되므로 둘이 다르게 동작합니다.
- **release 빌드는 `print()`를 버퍼에 모읍니다.** systemd 아래에서는 `피어 접속` 같은 로그가 journal에 바로 안 보입니다.
  `application/run/flush_stdout_on_print`를 켜야 합니다. `ERROR`는 stderr라서 바로 보입니다.
- **`--max-fps`가 없으면 headless 서버는 약 140fps로 돕니다.** 매 프레임 스냅샷을 보내므로 트래픽이 2배 넘게 늘어납니다.
- **https 페이지(Vercel)에서는 `ws://`가 막힙니다.** 그래서 도메인 + TLS(`wss://`)가 필요합니다.
- **`--export-release`는 문법이 깨진 스크립트도 성공으로 내보냅니다.** 내보내기 전에 `./t`를 돌리세요(`./build-server`가 합니다).
- **실행 중인 바이너리 위에 `scp`로 덮어쓰면 `Text file busy`로 실패합니다.** `.new`로 올리고 `mv`로 바꿔치기합니다(`./deploy-server`가 합니다).
- **macOS에서 큰 파일을 `scp`하면 `Result too large` / `lost connection`으로 중간에 끊길 수 있습니다.** `-o IPQoS=none`으로 해결됩니다.
  끊긴 업로드는 반쪽짜리 파일을 남기므로, `./deploy-server`는 해시가 맞을 때만 갈아 끼웁니다.
- **끊긴 업로드의 `sftp-server`가 서버에 남아 `.new`를 붙잡고 있으면**, 같은 이름으로 다시 올려 갈아 끼운 바이너리가
  `Text file busy`(systemd `203/EXEC`)로 실행되지 않고 서버가 내려갑니다. `./deploy-server`는 업로드 전에 `.new`를 지워 피합니다.
  이미 이 상태라면: `ps -eo pid,lstart,cmd | grep sftp-server`로 오래된 것을 `kill` 후 `sudo systemctl restart crazy-arcade`.

## 서버 갱신 (평소)

```bash
./build-server && ./deploy-server   # 보통은 이렇게

./build-server       # 테스트 → 서버 빌드 → x86_64 확인 (server-build/crazy-arcade-server.x86_64)
./build-server -s    # 테스트 건너뛰기
./deploy-server      # server-build/ 의 것을 업로드 → 재시작 → wss 101 확인 (빌드는 안 함)
```

접속 정보는 프로젝트 루트의 **`.deploy-server.env`** 에 둡니다. `.gitignore` 대상이라 도메인이 저장소에 남지 않습니다.
클론 직후에는 없으니 예시를 복사해서 채우세요.

```bash
cp .deploy-server.env.example .deploy-server.env    # DEPLOY_HOST, DEPLOY_USER, DEPLOY_KEY
```

아래 수동 명령의 `$DEPLOY_HOST`는 이 값입니다. 터미널에서 쓰려면 먼저 `source .deploy-server.env`를 하세요.
재시작하면 진행 중인 방과 전투는 모두 사라집니다.
`./deploy-server`는 빌드 뒤에 `src/`, `scenes/`, `assets/`, `project.godot`이 바뀌었으면 경고하고 Enter를 기다립니다.

클라이언트 갱신은 `./build-web` 후 `web-build/`를 Vercel에 배포합니다.

서버 접속(내 Mac에서):

```bash
source .deploy-server.env
ssh -i "$DEPLOY_KEY" "$DEPLOY_USER@$DEPLOY_HOST"
```

접속하지 않고 로그만 보려면 명령을 이어 붙입니다. `Ctrl+C`로 빠져나옵니다.

```bash
source .deploy-server.env
ssh -i "$DEPLOY_KEY" "$DEPLOY_USER@$DEPLOY_HOST" 'journalctl -u crazy-arcade -f'
```

| 하고 싶은 것 | 명령 (서버에서) |
|---|---|
| 로그 실시간 보기 | `journalctl -u crazy-arcade -f` |
| 최근 로그 100줄 | `journalctl -u crazy-arcade -n 100 --no-pager` |
| 특정 시각 이후 로그 | `journalctl -u crazy-arcade --since "10 min ago" --no-pager` |
| 상태 확인 | `systemctl status crazy-arcade --no-pager` |
| 재시작 / 멈춤 | `sudo systemctl restart crazy-arcade` / `sudo systemctl stop crazy-arcade` |
| Caddy 로그 | `sudo journalctl -u caddy -n 50 --no-pager` |

`print()`는 `피어 접속: <id>` / `피어 접속 끊김: <id>`처럼 바로 찍힙니다(`flush_stdout_on_print`).
서버가 재시작됐다면 `Started crazy-arcade.service` 다음에 `server listen on 8080`이 보여야 합니다.

## 서버를 처음부터 다시 만들기

### 1. 인스턴스 생성 (Oracle 콘솔)

| 항목 | 값 |
|---|---|
| Image | Canonical Ubuntu 24.04 **Minimal** (x86_64, aarch64 아닌 것) |
| Shape | `VM.Standard.E2.1.Micro` ("Always Free-eligible" 확인) |
| Shielded instance | 끔 |
| Primary VNIC | 공용(public) 서브넷, **Public IPv4 자동 할당 켬** |
| SSH 키 | 기존 `~/.ssh/oracle.key.pub`를 "Upload public key files"로 올림 |

- ARM(`VM.Standard.A1.Flex`)으로 가려면 이미지를 **aarch64**로, 내보내기 아키텍처를 **arm64**로 바꿉니다.
  오사카는 A1 자리가 자주 없습니다(Out of capacity). 사양을 줄이거나 시간을 두고 재시도합니다.
- 공용 IP가 안 붙었으면: 인스턴스 → Networking → Primary VNIC → IPv4 Addresses → Edit → Ephemeral public IP.
- 새 IP가 생겼으면 **도메인 DNS의 A 레코드를 새 IP로 바꿉니다.** 클라이언트는 다시 빌드하지 않아도 됩니다.

### 2. 접속과 기본 세팅 (서버에서)

```bash
ssh -i ~/.ssh/oracle.key ubuntu@<공용 IP>

# 스왑 2GB — 업데이트보다 먼저. 메모리 1GB라 apt가 멈출 수 있습니다.
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Seoul
sudo reboot    # "System restart required"가 보이면
```

Minimal 이미지에는 `nano`가 없습니다. 아래 파일들은 `tee`로 씁니다.

### 3. 방화벽 (두 겹 모두)

**① Oracle 콘솔 — Security List**: VCN → Subnet → Default Security List → Add Ingress Rules

| Source CIDR | Protocol | Source Port | Destination Port |
|---|---|---|---|
| `0.0.0.0/0` | TCP | (비움) | `80,443` |

**② 서버 안 — iptables**: Oracle 이미지에는 맨 끝에 REJECT 규칙이 있으므로 그보다 **위에** 넣습니다.

```bash
sudo iptables -L INPUT --line-numbers -n          # REJECT 줄 번호 확인 (예: 5)
sudo iptables -I INPUT 5 -p tcp --dport 80  -m state --state NEW -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 443 -m state --state NEW -j ACCEPT
sudo netfilter-persistent save
```

- **8080은 열지 않습니다.** 외부에서는 Caddy를 거쳐서만 들어옵니다.
- **`ufw enable` 금지.** 기존 iptables 규칙과 꼬여 SSH가 막힙니다.

### 4. Caddy

Caddy 공식 저장소(Cloudsmith)는 전송량 한도로 `402 Payment Required`를 낸 적이 있습니다. Ubuntu 저장소 판으로 충분합니다.

```bash
sudo apt install -y caddy

sudo tee /etc/caddy/Caddyfile > /dev/null <<'EOF'
<게임 서버 도메인> {
	reverse_proxy localhost:8080
}
EOF
sudo systemctl reload caddy
```

`reverse_proxy`는 WebSocket도 그대로 넘깁니다. 확인(내 Mac에서):

```bash
curl -I https://$DEPLOY_HOST    # 게임 서버 띄우기 전: HTTP/2 502 = 정상 (TLS 됨, 8080 비어 있음)
```

봇이 보내는 일반 HTTP 요청이 게임 서버 로그에 `Missing or invalid header 'upgrade'`로 찍힙니다. 해롭지 않습니다.
거르고 싶으면 WebSocket 요청만 넘깁니다. `handle`로 감싸지 않으면 `respond`가 먼저 처리돼 전부 404가 됩니다.

```
<게임 서버 도메인> {
	@ws {
		header Connection *Upgrade*
		header Upgrade websocket
	}
	handle @ws {
		reverse_proxy localhost:8080
	}
	handle {
		respond 404
	}
}
```

### 5. 게임 서버 올리기 + systemd

```bash
# 내 Mac에서
ssh -i ~/.ssh/oracle.key ubuntu@$DEPLOY_HOST 'mkdir -p ~/crazy-arcade'
scp -i ~/.ssh/oracle.key server-build/crazy-arcade-server.x86_64 \
    ubuntu@$DEPLOY_HOST:~/crazy-arcade/crazy-arcade-server.x86_64
```

```bash
# 서버에서 — 먼저 손으로 한 번. "server listen on 8080"이 보이면 Ctrl+C
~/crazy-arcade/crazy-arcade-server.x86_64 --headless --max-fps 60

sudo tee /etc/systemd/system/crazy-arcade.service > /dev/null <<'EOF'
[Unit]
Description=Petit Crazy Arcade game server
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/crazy-arcade
ExecStart=/home/ubuntu/crazy-arcade/crazy-arcade-server.x86_64 --headless --max-fps 60
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now crazy-arcade
```

### 6. 확인

```bash
# 내 Mac에서 — "HTTP/1.1 101 Switching Protocols"가 나오면 Caddy → 게임 서버까지 연결된 것
curl -sS -i -N --http1.1 --max-time 4 \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://$DEPLOY_HOST | head -1
```

마지막으로 Vercel 페이지를 열어 로비가 뜨고, 서버 로그에 `피어 접속: <id>`가 찍히는지 봅니다.

## Oracle 계정 메모

- 홈 리전은 가입 때 한 번 고르면 못 바꿉니다. 가입 목록에 한국 리전이 없어서 오사카를 골랐습니다.
- **Free Tier 계정의 Always Free 인스턴스는 7일간 사용률이 낮으면 회수될 수 있습니다**(회수 전 이메일 경고).
  PAYG(종량제)로 올리면 회수 대상에서 빠지고, 무료 한도 안에서는 0원입니다. 올리기 전에 예산 알림을 겁니다
  (Billing & Cost Management → Budgets, root compartment, 월 1달러, Actual Spend 1%).
- 카드 등록·업그레이드 때 카드 확인용 임시 승인이 잡혔다가 취소됩니다.
