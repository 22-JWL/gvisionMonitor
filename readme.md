# GVision Monitor

---

## 수상 사진

<img src="./image.jpg" alt="캡스톤디자인 우수상 수상 사진" width="100%" />

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [시스템 구성도](#2-시스템-구성도)
3. [디렉토리 구조](#3-디렉토리-구조)
4. [컴포넌트별 상세 설명](#4-컴포넌트별-상세-설명)
5. [개발 환경 설정](#5-개발-환경-설정)
6. [실행 방법](#6-실행-방법)
7. [API 명세](#7-api-명세)
8. [데이터베이스 구조](#8-데이터베이스-구조)
9. [주요 설정값](#9-주요-설정값)
10. [자주 발생하는 문제 및 해결법](#10-자주-발생하는-문제-및-해결법)
11. [Git 브랜치 전략](#11-git-브랜치-전략)

---

## 1. 프로젝트 개요

**GVision Monitor**는 반도체 검사 라인의 **실시간 장비 모니터링 및 검사 분석 시스템**입니다.

### 주요 기능

- 장비 실시간 상태 추적 (동작 모드, 레시피, Lot 번호)
- 이벤트 로그 모니터링 및 알림
- 검사 품질 분석 (수율, 불량 유형, XY 히트맵)
- Lot 이력 추적 및 통계
- 모바일 앱 + 웹 대시보드 이중 인터페이스

### 기술 스택 요약

| 구분         | 기술                                               |
| ------------ | -------------------------------------------------- |
| 백엔드       | Node.js, Express 5, WebSocket (ws), better-sqlite3 |
| 모바일 앱    | Flutter / Dart, Provider, FL Chart                 |
| 대시보드     | Grafana, frser-sqlite-datasource 플러그인          |
| 데이터베이스 | SQLite (읽기 전용 GvisionWpf DB + 상태 기록용 DB)  |

---

## 2. 시스템 구성도

```
┌─────────────────────────────────────────────────────────┐
│                    GVision Monitor                      │
│                                                         │
│  ┌──────────────┐    ┌─────────────────────────────┐   │
│  │  GvisionWpf  │───>│       Node.js Server        │   │
│  │  (외부 앱)   │    │    (server/, port 4000)     │   │
│  │  DS_HanaMi-  │    │  - REST API                 │   │
│  │  cron.db     │    │  - WebSocket 브로드캐스트   │   │
│  └──────────────┘    │  - DB 폴링 (3~5초 주기)     │   │
│                       └────────┬────────────────────┘   │
│                                │                        │
│                    ┌───────────┼───────────┐            │
│                    │           │           │            │
│            ┌───────▼──┐  ┌────▼────┐  ┌──▼──────────┐ │
│            │  Flutter  │  │Grafana  │  │gvision_     │ │
│            │  Mobile   │  │Dashboard│  │status.db    │ │
│            │  App      │  │(port    │  │(data/ 폴더) │ │
│            │           │  │ 3000)   │  │             │ │
│            └───────────┘  └─────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**데이터 흐름:**

1. GvisionWpf가 장비 데이터를 SQLite DB에 기록
2. Node.js 서버가 해당 DB를 3~5초마다 폴링
3. 변경 감지 시 WebSocket으로 연결된 클라이언트에 브로드캐스트
4. 서버가 `gvision_status.db`에 현재 상태 기록 (Grafana가 읽음)
5. Flutter 앱은 WebSocket으로 실시간 업데이트 수신 + REST API로 상세 데이터 조회

---

## 3. 디렉토리 구조

```
C:\Users\Administrator\gvision-monitor\
│
├── server/                    # Node.js 백엔드 서버
│   ├── index.js               # 서버 진입점
│   ├── config.js              # 설정값 (포트, DB 경로, 폴링 주기)
│   ├── db.js                  # GvisionWpf DB 읽기 전용 쿼리 모음
│   ├── statusDb.js            # gvision_status.db 쓰기 인터페이스
│   ├── poller.js              # 상태/이벤트/Lot 폴링 로직
│   ├── websocket.js           # WebSocket 서버 및 브로드캐스트
│   ├── seed-dummy.js          # 테스트용 더미 데이터 생성
│   ├── package.json
│   └── routes/
│       ├── status.js          # /api/status/* 엔드포인트
│       ├── events.js          # /api/events/* 엔드포인트
│       ├── inspections.js     # /api/inspections/* 엔드포인트
│       └── lots.js            # /api/lots/* 엔드포인트
│
├── gvision_app/               # Flutter 모바일 앱
│   ├── pubspec.yaml           # 의존성 정의
│   └── lib/
│       ├── main.dart          # 앱 진입점, Provider 설정, 네비게이션
│       ├── core/
│       │   ├── api/           # HTTP API 클라이언트 모음
│       │   │   ├── api_client.dart       # 기본 HTTP 클라이언트 (IP/포트 설정)
│       │   │   ├── events_api.dart
│       │   │   ├── inspections_api.dart
│       │   │   ├── lots_api.dart
│       │   │   └── status_api.dart
│       │   ├── models/        # 데이터 모델 (DeviceStatus, GvisionEvent, Lot 등)
│       │   ├── providers/     # 앱 전역 상태 관리
│       │   └── ws/
│       │       └── ws_client.dart  # WebSocket 연결 (자동 재연결 포함)
│       ├── features/
│       │   ├── home/          # 장비 상태 + 최근 이벤트 화면
│       │   ├── inspection/    # 검사 품질 분석 (수율, 불량, 히트맵)
│       │   ├── events/        # 이벤트 로그 화면
│       │   ├── lots/          # Lot 이력 화면
│       │   └── settings/      # 서버 IP/포트 설정 화면
│       └── services/
│           ├── notification_service.dart  # 로컬 푸시 알림
│           └── lot_memo_service.dart
│
├── grafana/
│   └── dashboards/
│       ├── 01-realtime-status.json      # 실시간 장비 상태 대시보드
│       ├── 02-inspection-quality.json   # 검사 품질 분석 대시보드
│       ├── 03-events-context.json       # 이벤트 타임라인 대시보드
│       └── 04-lot-history.json          # Lot 이력 대시보드
│
├── data/
│   └── gvision_status.db      # 서버가 기록하는 현재 상태 DB (Grafana 연동용)
│
├── dash01-check.json          # 대시보드 검증용 파일
└── .gitignore
```

---

## 4. 컴포넌트별 상세 설명

### 4-1. 백엔드 서버 (`server/`)

**역할:** GvisionWpf DB를 주기적으로 폴링하여 변경사항을 감지하고, REST API와 WebSocket으로 클라이언트에 제공

**핵심 파일 역할:**

| 파일           | 역할                                                         |
| -------------- | ------------------------------------------------------------ |
| `config.js`    | 서버 포트(4000), DB 경로, 폴링 주기 등 모든 설정값 중앙 관리 |
| `db.js`        | GvisionWpf DB에 대한 모든 SELECT 쿼리 함수 정의              |
| `poller.js`    | 5초 주기로 장비 상태 폴링, 3초 주기로 이벤트 감지            |
| `websocket.js` | WebSocket 클라이언트 관리, 이벤트 발생 시 전체 브로드캐스트  |
| `statusDb.js`  | 현재 상태(모드/레시피/Lot)를 `gvision_status.db`에 upsert    |

**WebSocket 메시지 타입:**

```javascript
{ type: 'STATUS',         data: { runningMode, recipeName, lotNo } }
{ type: 'NEW_EVENT',      data: { Id, Time, LogType, Description, LotId, ... } }
{ type: 'ALERT',          data: { ... } }
{ type: 'GVISION_OFFLINE', data: {} }
```

---

### 4-2. Flutter 앱 (`gvision_app/`)

**역할:** WebSocket으로 실시간 장비 상태를 수신하고, REST API로 검사 데이터를 조회하는 모바일 앱

**화면 구성 (하단 탭 기준):**

| 탭         | 화면        | 주요 내용                               |
| ---------- | ----------- | --------------------------------------- |
| Home       | 장비 상태   | 동작 모드, 현재 레시피/Lot, 최근 이벤트 |
| Inspection | 검사 품질   | 수율 그래프, 불량 유형 차트, XY 히트맵  |
| Events     | 이벤트 로그 | 이벤트 목록, 전후 컨텍스트 조회         |
| Lots       | Lot 이력    | Lot 목록, 통계, 메모 기능               |
| Settings   | 설정        | 서버 IP/포트 변경                       |

**상태 관리:** Provider 패턴 사용. 각 feature 폴더 내 `*_provider.dart`가 상태를 관리하고 화면(`*_screen.dart`)은 UI만 담당.

**서버 연결 설정:** 기본값 `192.168.0.34:4000`. Settings 화면에서 변경 가능하며 SharedPreferences에 저장됨.

---

### 4-3. Grafana 대시보드 (`grafana/`)

**역할:** SQLite datasource와 HTTP API를 활용한 고급 분석 시각화

**사용 플러그인:** `frser-sqlite-datasource` (Grafana에 별도 설치 필요)

**데이터 소스 2종:**

- **SQLite**: `data/gvision_status.db` 직접 읽기 → 실시간 상태 패널
- **HTTP API**: 백엔드 `/api/inspections/*` 호출 → 분석 패널

---

## 5. 개발 환경 설정

### 필수 설치 항목

| 도구        | 버전          | 용도                   |
| ----------- | ------------- | ---------------------- |
| Node.js     | v20 이상 권장 | 백엔드 서버 실행       |
| Flutter SDK | 3.11.4 이상   | 모바일 앱 개발         |
| Grafana     | 최신 버전     | 대시보드 (Docker 권장) |
| Git         | -             | 버전 관리              |

### 백엔드 초기 설정

```bash
cd server
npm install
```

### Flutter 앱 초기 설정

```bash
cd gvision_app
flutter pub get
```

### Grafana 설정 (Docker)

```bash
docker run -d \
  -p 3000:3000 \
  -v grafana-storage:/var/lib/grafana \
  -e "GF_INSTALL_PLUGINS=frser-sqlite-datasource" \
  grafana/grafana
```

이후 `http://localhost:3000`에서 대시보드 JSON 파일을 import.

---

## 6. 실행 방법

### 백엔드 서버 실행

```bash
cd server

# 운영 환경
npm start

# 개발 환경 (파일 변경 시 자동 재시작)
npm run dev
```

서버 주소: `http://localhost:4000`  
WebSocket: `ws://localhost:4000/ws`

### Flutter 앱 실행

```bash
cd gvision_app

# Android / iOS
flutter run

# Windows 데스크탑
flutter run -d windows
```

### 테스트 데이터 생성 (개발용)

```bash
cd server

# 3시간치 더미 데이터 삽입
node seed-dummy.js

# 더미 데이터 제거
node seed-dummy.js --clean
```

> **주의:** 실제 GvisionWpf DB가 없는 환경에서 개발 시 seed-dummy.js로 테스트 데이터를 생성하여 사용.

---

## 7. API 명세

**Base URL:** `http://SERVER_IP:4000`

### 상태 API

| Method | Endpoint             | 설명              | 응답                                  |
| ------ | -------------------- | ----------------- | ------------------------------------- |
| GET    | `/health`            | 서버 헬스체크     | `{ status: 'ok', time: ISO }`         |
| GET    | `/api/status`        | 장비 전체 상태    | `{ rows: [{ connectedClients: N }] }` |
| GET    | `/api/status/mode`   | 동작 모드 (CSV)   | `0=OFFLINE, 1=Run, 2=SetUp`           |
| GET    | `/api/status/recipe` | 현재 레시피 (CSV) | 레시피명                              |
| GET    | `/api/status/lot`    | 현재 Lot (CSV)    | Lot 번호                              |

### 이벤트 API

| Method | Endpoint                  | 설명                      | 쿼리 파라미터              |
| ------ | ------------------------- | ------------------------- | -------------------------- |
| GET    | `/api/events`             | 최근 이벤트 목록          | `limit=50`, `logType=1~5`  |
| GET    | `/api/events/:id/context` | 특정 이벤트 전후 컨텍스트 | `before=5`, `after=5` (분) |

**LogType 값:**

| 값  | 의미              |
| --- | ----------------- |
| 1   | System 이벤트     |
| 2   | Inspection 이벤트 |
| 4   | LOT 이벤트        |
| 5   | Recipe 이벤트     |

### 검사 API

| Method | Endpoint                    | 설명                   | 쿼리 파라미터                    |
| ------ | --------------------------- | ---------------------- | -------------------------------- |
| GET    | `/api/inspections/series`   | 원시 검사 결과         | `from`, `to` (ISO 8601), `lotId` |
| GET    | `/api/inspections/yield`    | 수율 시계열 (1분 단위) | `from`, `to`, `lotId`            |
| GET    | `/api/inspections/duration` | 처리 시간 시계열       | `from`, `to`, `lotId`            |
| GET    | `/api/inspections/errors`   | 불량 유형별 집계       | `lotId` 또는 `today=1`           |
| GET    | `/api/inspections/heatmap`  | XY 위치별 불량 히트맵  | `lotId` (필수)                   |

### Lot API

| Method | Endpoint              | 설명               | 쿼리 파라미터 |
| ------ | --------------------- | ------------------ | ------------- |
| GET    | `/api/lots`           | Lot 목록           | `limit=20`    |
| GET    | `/api/lots/:id/stats` | 특정 Lot 수율 통계 | -             |

---

## 8. 데이터베이스 구조

### GvisionWpf DB (읽기 전용)

**위치:** `C:/givision-AML/GvisionWpf/bin/x64/Debug/net9.0-windows/DB/Schema/DS_HanaMicron.db`

> 이 파일은 GvisionWpf 외부 앱이 생성 및 관리. 우리 시스템은 **읽기 전용**으로만 접근.

| 테이블               | 주요 컬럼                                                                    | 설명                                |
| -------------------- | ---------------------------------------------------------------------------- | ----------------------------------- |
| `histories`          | Id, Time, LogType, Description, LotId, Camera                                | 시스템/검사/Lot 이벤트 로그         |
| `inspection_results` | Id, LotId, RecipeName, StartTime, Duration, Item, XPos, YPos, InspectionType | 개별 검사 결과 (핵심 시계열 데이터) |
| `lot`                | Id, LotNumber, Package, StartTime, EndTime                                   | Lot 마스터 정보                     |

**`inspection_results.Item` 값:**

- `PASS` → 정상
- 그 외 → 불량 유형 코드 (에러 분류에 사용)

### 상태 DB (읽기/쓰기)

**위치:** `C:\Users\Administrator\gvision-monitor\data\gvision_status.db`

| 테이블           | 컬럼                        | 설명                     |
| ---------------- | --------------------------- | ------------------------ |
| `current_status` | key (PK), value, updated_at | 현재 상태 key-value 저장 |

**저장되는 key 목록:**

| Key           | 예시 값         | 설명                      |
| ------------- | --------------- | ------------------------- |
| `runningMode` | `1`             | 0=OFFLINE, 1=Run, 2=SetUp |
| `recipeName`  | `AML_RECIPE_01` | 현재 레시피명             |
| `lotNo`       | `LOT2024050001` | 현재 Lot 번호             |

---

## 9. 주요 설정값

**`server/config.js` 에서 변경 가능한 설정:**

| 설정 키                  | 기본값                                 | 설명                       |
| ------------------------ | -------------------------------------- | -------------------------- |
| `SERVER_PORT`            | `4000`                                 | 백엔드 API 포트            |
| `GVISION_API_URL`        | `http://localhost:3000`                | GvisionWpf 업스트림 API    |
| `DB_PATH`                | `C:/givision-AML/.../DS_HanaMicron.db` | GvisionWpf DB 절대 경로    |
| `POLL_INTERVAL_MS`       | `5000`                                 | 장비 상태 폴링 주기 (ms)   |
| `EVENT_POLL_INTERVAL_MS` | `3000`                                 | 이벤트 감지 폴링 주기 (ms) |

> DB_PATH는 실제 운영 PC의 경로에 맞게 수정 필요.

**Flutter 앱 기본 서버 설정:**

`lib/core/api/api_client.dart` 내 기본값:

- 기본 Host: `192.168.0.34`
- 기본 Port: `4000`

앱 실행 후 Settings 화면에서 변경 가능. 변경값은 SharedPreferences에 저장되어 재시작 시에도 유지됨.

---

## 10. 자주 발생하는 문제 및 해결법

### 서버가 DB를 못 찾는 경우

**증상:** 서버 실행 시 `SQLITE_CANTOPEN` 오류

**원인:** `config.js`의 `DB_PATH`가 실제 GvisionWpf DB 경로와 다름

**해결:** `server/config.js`에서 `DB_PATH`를 실제 경로로 수정

---

### Flutter 앱이 서버에 연결 안 되는 경우

**증상:** 앱 실행 후 데이터가 로드되지 않음

**원인:** 서버 IP/포트 설정 불일치 또는 서버 미실행

**해결:**

1. 서버가 실행 중인지 확인 (`npm start`)
2. 앱 Settings 화면에서 서버 IP를 운영 PC의 실제 IP로 변경
3. 방화벽에서 4000번 포트 허용 확인

---

### Grafana에서 데이터가 안 나오는 경우

**증상:** 대시보드 패널이 비어 있음

**원인 1:** `frser-sqlite-datasource` 플러그인 미설치  
**해결:** Grafana 재실행 시 플러그인 설치 옵션 포함 (`-e "GF_INSTALL_PLUGINS=frser-sqlite-datasource"`)

**원인 2:** SQLite datasource의 DB 경로 오설정  
**해결:** Grafana 데이터소스 설정에서 `gvision_status.db`의 절대 경로 확인

---

### WebSocket 연결이 자주 끊기는 경우

**증상:** 앱이 실시간 업데이트를 받지 못하고 재연결 반복

**원인:** 네트워크 불안정 또는 서버 메모리 부족

**참고:** `ws_client.dart`에 자동 재연결 로직이 구현되어 있어 일시적 단절은 자동 복구됨.  
지속적으로 발생한다면 서버 로그를 확인.

---

## 참고 사항

- **외부 의존성:** GvisionWpf 앱이 별도로 운영 중이어야 함. 해당 앱이 없으면 실제 데이터가 없으므로 `seed-dummy.js`로 테스트.
- **DB 파일 제외:** `.gitignore`에 `*.db` 포함되어 있어 DB 파일은 Git에 포함되지 않음.
- **코드 언어:** 백엔드 코드 주석 일부가 한국어로 작성되어 있음.
