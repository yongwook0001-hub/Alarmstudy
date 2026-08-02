# S.O.S - Solve to Stop — 작업 인수인계 프롬프트 (Claude Code CLI용)

이 프롬프트를 Claude Code CLI(터미널)에 그대로 붙여넣어서 이어서 작업 시켜.
프로젝트 루트(`alarm_study/`)에서 실행할 것.

## 프로젝트 개요

Flutter 알람/학습 앱 "S.O.S - Solve to Stop". 학습자료를 올리면 AI(Gemini)가 요약+퀴즈를 만들고,
알람이 울리면 그 퀴즈를 풀어야 알람이 꺼짐. 백엔드는 FastAPI + Postgres.
프론트는 `develop` 브랜치에서 나(용욱)와 프론트 담당, 백엔드는 팀원이 `back` 브랜치에서 작업 후 병합.

## 현재 브랜치/구조

- 현재 브랜치: `develop` (origin과 동기화됨, 최근 팀원 백엔드 22커밋 병합 완료)
- `lib/screens/{home,alarm,study_material,my_page,auth}/` — 화면 4탭 + 인증 화면 폴더 분리 완료
- `lib/widgets/` — 공통 위젯 (SectionTitle, SettingsGroup, TextInputField, PrimaryButton)
- `lib/state/app_data.dart` — 알람/학습자료 리스트 상태 + 알람 스케줄링 사이드이펙트 관리
- `lib/data/sample_data.dart` — 목업 초기 데이터
- `lib/services/` — `ai_service.dart`(요약), `auth_service.dart`(로그인/JWT), `song_service.dart`(AI 노래),
  `alarm_scheduler.dart`(실기기 알람), `user_session.dart`
- `server/app/api/` — `auth.py`, `alarms.py`, `materials.py`, `sets.py`, `sessions.py`, `stats.py`, `song.py`

## 지금까지 구현된 것 (동작 확인됨)

1. **UI 전체** — 온보딩/로그인/홈/알람설정/알람추가/학습자료/AI요약/마이페이지, 다크·라이트 테마 토글
2. **구글/카카오 로그인** — `AuthService`가 실제 백엔드 `/api/auth/login`, `/refresh`, `/logout`, `/api/users/me` 호출, JWT를 `flutter_secure_storage`에 저장. 단, **앱 재시작 시 로그인 유지 로직은 없음** (매번 새로 로그인해야 함 — `user_session.dart`에 TODO로 남겨둠)
3. **AI 요약/퀴즈 생성** — `AiService`가 백엔드의 레거시 엔드포인트 `POST /summarize`, `/summarize/pdf` 호출 (Gemini 직접 연동, DB 저장 없음 — 결과는 프론트 메모리에만 존재)
4. **AI 노래 생성** — `SongService` → `POST /api/songs/generate` (Lyria) 연동 완료, 로컬 파일로 저장해서 미리듣기 + 알람음으로 지정 가능
5. **실제 OS 알람 스케줄링** — `alarm` 패키지로 앱이 꺼져있어도 지정 시간에 실제로 울림. 요일 반복은 앱이 직접 "다음 발생 시각" 계산해서 매번 재예약하는 방식 (`AlarmScheduler`)
6. **기본 알람음 4종 + 커스텀(AI 생성) 알람음** 선택 UI

## 아직 안 된 것 / 알아야 할 갭

**가장 중요한 갭**: 백엔드에 이미 완성된 진짜 REST API(`/api/alarms` CRUD, `/api/materials`, `/api/sets`, `/api/sessions`, `/api/stats` — 전부 팀원이 DB까지 붙여서 구현해놓음)가 있는데, **프론트는 아직 이걸 하나도 호출하지 않음**. `lib/state/app_data.dart`가 여전히 `sample_data.dart`의 목업 리스트를 메모리에서만 관리 중 — 즉 지금 앱을 껐다 켜면 만든 알람/학습자료가 전부 사라짐. 실제 서비스가 되려면 이 부분(로그인한 유저의 알람/학습자료를 서버에 저장하고 앱 시작 시 불러오기)을 프론트에서 연결해야 함.

세부적으로:
- `POST/GET/PATCH/DELETE /api/alarms` — 알람 CRUD (스키마: `alarm_time`(HH:MM), `set_id`, `repeat_days`(int 비트마스크로 추정, 서버 코드 확인 필요), `is_enabled`, `label`, `sound`, `volume`, `is_vibration`)
- `/api/materials` — 학습자료 업로드 (지금 프론트가 쓰는 `/summarize`, `/summarize/pdf`와는 별개 흐름 — 파일을 S3에 올리고 `upload-complete`로 완료 통보하는 방식으로 보임, 코드 확인 필요)
- `/api/sets` — "세트" 개념 (학습자료 묶음으로 추정, `alarms.set_id`가 여길 가리킴)
- `/api/sessions` — 알람 울렸을 때 퀴즈 풀이 세션/시도 기록
- `/api/stats` — 오답노트, 취약분석, 통계 요약
- 로그인 세션 유지 (앱 시작 시 저장된 토큰으로 `AuthService.getMe()` 호출해서 자동 로그인)
- `server/app/core/config.py`가 이제 `AWS_REGION`, `S3_BUCKET_NAME`을 필수로 요구함(팀원이 S3 연동 추가) — 로컬 `.env`에 아직 이 값들 + `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`가 없어서 **백엔드가 지금 상태로는 기동이 안 될 수 있음** (팀원한테 값 받아야 함)
- GCP Cloud Run 배포는 중간에 멈춘 상태 (Cloud SQL 인스턴스, Artifact Registry는 만들어놨지만 실제 배포는 안 함) — AWS 배포도 아직 안 함, 지금 뜬 서버 없음

## 로컬 실행 방법

백엔드:
```
cd server
uvicorn app.main:app --reload
```
(먼저 `.env`에 `AWS_REGION`/`S3_BUCKET_NAME`/`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` 채워야 기동될 수 있음 — 팀원에게 확인)

프론트 (에뮬레이터 기준):
```
flutter run
```
루트 `.env`의 `API_BASE_URL`이 `http://10.0.2.2:8000`(에뮬레이터용)로 되어 있는지 확인. 실기기 테스트 시엔 PC의 LAN IP로 바꿔야 함.

## 다음에 할 일 (우선순위 순 제안)

1. 백엔드 `AWS_*` 환경변수 팀원에게 받아서 `.env`에 채우고 서버 기동 확인
2. `server/app/api/materials.py`, `sets.py` 코드 읽고 실제 계약 파악
3. `lib/state/app_data.dart`를 로컬 목업 대신 실제 API 호출로 교체:
   - 앱 시작 시 `/api/alarms`, 학습자료 관련 API로 목록 로드
   - 알람 추가/수정/삭제(`AlarmListScreen`의 Switch, `AlarmAddScreen` 저장)를 서버에 반영
   - 로그인 안 된 상태 처리(비로그인 시 로컬 전용으로 둘지, 로그인 강제할지 정책 결정 필요)
4. 앱 시작 시 저장된 토큰으로 자동 로그인 (`user_session.dart`의 TODO)
5. 알람 울림 → 퀴즈 풀이 → `/api/sessions` 기록 연결 (지금은 로컬에서만 퀴즈 진행, 서버 기록 없음)
6. (선택) GCP Cloud Run 배포 재개 — Cloud SQL/Artifact Registry는 이미 있음, 남은 건 Secret Manager, Alembic 마이그레이션, `gcloud run deploy`

## 작업 시 주의사항

- 프론트 UI/동작은 이미 리팩토링 완료 상태 — 불필요하게 다시 건드리지 말 것
- `AppData.alarms`/`materials` 리스트는 참조를 유지해야 하는 곳들이 있음 (자식 화면이 객체를 직접 mutate) — API 연동 시 이 패턴 깨지 않게 주의
- 백엔드 코드(`server/app/`)는 팀원 소유 — 구조 크게 바꾸지 말고, 필요한 건 확인 후 진행
