# 개발 가이드

Godot 4.7 + GDScript + GdUnit4 6.1.3

## 셋업

```bash
brew install --cask godot
```

## 실행

```bash
./run -h                            # 사용법
./run                               # 게임 실행 (project.godot 의 main_scene)
./run scenes/frame_counter.tscn     # 특정 씬만 실행
./run -e                            # Godot 에디터 열기
```

**VSCode에서 개발할 때 Godot 에디터를 띄워두세요.** GDScript의 언어 서버(LSP)는 독립 실행되지 않고 Godot 에디터 안에 들어 있습니다(`127.0.0.1:6005`). 따라서 Godot 에디터를 띄워둬야 자동완성과 문법 에러 확인이 가능합니다.

## 멀티플레이어

```bash
./run scenes/server.tscn    # 터미널 1: 서버
./run                       # 터미널 2: 클라이언트
```

## 테스트

```bash
./t -h                             # 사용법
./t                                # 전체
./t test/core                      # 디렉터리
./t test/core/water_balloon_test.gd  # 파일 하나
./t -w                             # 감시 모드
./t -w -g test/game                # 감시 + 창
./t --clean                        # reports/ 와 .godot/ 캐시 삭제
```

## 웹 빌드

```bash
./build -h                  # 사용법
./build                     # 테스트 후 web-build/index.html 로 내보내기
./build -d                  # 디버그 빌드 (브라우저 콘솔에 스택 트레이스)
./build -s                  # 테스트 건너뛰기
./build dist/index.html     # 다른 경로로 (상대 경로는 프로젝트 루트 기준)
```

**내보내기 전에 테스트를 돌립니다.** `--export-release`는 스크립트를 컴파일하지 않습니다.
문법이 깨진 `.gd`도 `.gdc`로 그대로 패킹하고 종료 코드 0으로 끝냅니다. `--import`도 같습니다.
둘 다 초록불을 주고 브라우저를 열어야 비로소 죽으므로, 실제로 걸러내는 건 테스트뿐입니다.

결과물은 `file://`로 열리지 않습니다. Godot이 `.pck`를 fetch로 읽는데 `file://`은 CORS에
막힙니다. HTTP로 띄우세요. 빌드가 끝나면 그 명령을 찍어줍니다.

`export_presets.cfg`는 `.gitignore` 대상이라 클론에는 안 따라옵니다. 없으면 `./build`가
무엇을 해야 하는지 알려주고 멈춥니다.

`./t`, `./run`, `./build`는 각각 `bin/test.sh`, `bin/run.sh`, `bin/build.sh`를 부르는 한 줄짜리
단축 실행기입니다. 플래그는 자유롭게 조합됩니다. Godot 실행 파일을 찾는 로직은
`bin/_godot.sh`에 한 번만 두고 셋이 공유합니다.

## 구조

```
src/core/     게임 규칙. RefCounted 기반, 엔진 의존 없음. 로직 대부분이 여기 살아야 함
src/game/     Node 레이어. 엔진에 배선하는 얇은 껍데기
scenes/       .tscn 씬 파일
test/core/    순수 로직 테스트 (빠름, 결정론적)
test/game/    씬 테스트 (scene_runner로 프레임 시뮬레이션)
docs/         개발 문서
tools/        에셋을 굽는 스크립트. 게임 실행에는 안 쓰인다
addons/gdUnit4/  테스트 프레임워크 (v6.1.3, 커밋에 포함)
```

## 용어

| 도메인 | 코드 | 뜻 |
|---|---|---|
| 맵 | `Map` | 격자와 그 위에 놓인 것들 |
| 캐릭터 | `Character` | 칸 단위로 움직이고 물풍선을 놓는다 |
| NPC | `Npc` | 컴퓨터가 조종하는 캐릭터 |
| 물풍선 | `WaterBalloon` | 캐릭터가 칸에 놓는 것 |
| 물줄기 | `WaterStream` | 물줄기의 한 칸 |
| 물방울 | `Bubble` | 물줄기에 맞은 캐릭터가 갇히는 상태 |
| 배틀 | `Battle` | 한 판의 대국. 맵을 소유하고 승패를 판정한다 |
| 배틀 모드 | `BattleMode` | 배틀을 시작할 때 각 자리를 누가 조종할지 짜는 방식 |
| 협공배틀 | `MONSTER` | 배틀 모드. 사람들이 한 팀이 되어 NPC와 싸운다. 사람은 하나일 수도 둘일 수도 있다 |
| 로컬 멀티플레이어 | `LOCAL_MULTI` | 배틀 모드. 1P와 2P를 사람 둘이 조종한다. 한 키보드를 나눠 쓴다 |
| 온라인 멀티플레이어 | `ONLINE_MULTI` | 배틀 모드. 네트워크를 통해 서로 다른 플레이어가 플레이한다 |
| 게임키 | `GameKey` | 플레이어가 쓰는 키 묶음 |
| 팀 | `Team` | 캐릭터의 색상으로 구분한다 |
| 방 | `Room` | 게임을 시작하기 전 캐릭터들이 모이는 곳 |
| 로비 | `Lobby` | 방들이 있는 곳 |
| 피어 | `peer` | 서버에 접속한 클라이언트 하나. 접속할 때 서버가 ID를 준다. 서버 자신은 항상 1 |
| 서버 | `Server` | 피어들의 접속을 받는 씬. 게임 화면이 없고 따로 띄운다 |
| 화면 | `Game` | 씬 루트. 로비/방/배틀 중 지금 무엇을 보여줄지 결정한다. 화면이 바뀌어도 로비와 방을 붙들고 있다 |
| 배틀 화면 | `BattleView` | 배틀을 밖에서 받아 그리고 조작을 받는다. 배틀을 스스로 만들지 않는다 |
| 자리 | `number` | 배틀에 참가한 한 사람 몫. 1P, 2P. 방에 들어올 때 빈 번호를 받는다 |
| 내 캐릭터 | `player_character` | 이 클라이언트가 조종하는 캐릭터. 방을 옮겨다닌다 |
| 2P | `second_player` | 로컬 멀티에서 같은 키보드를 나눠 쓰는 두 번째 사람. 방에서 직접 추가한다 |
| 타일 | `tile` | 맵 바닥의 한 칸. 같은 톤의 변형 두 장을 섞어 깐다. 경계선은 긋지 않고, 얼룩이 반복되면서 칸이 저절로 드러난다 |
| 슬롯 | `slot` | 방 화면에서 캐릭터 하나가 앉은 자리 |
| 방 항목 | `room_entry` | 로비 화면 방 목록의 한 줄. 누르면 그 방에 입장한다 |
| 게임 아이템 | `GameItem` | 맵에서 캐릭터가 획득하는 것. 물풍선, 물줄기, 스피드 등 |
| 방향 | `Direction` | 캐릭터의 이동 방향. 상하좌우 |
