# 🔔 Alarm Study — 알람 스터디

> 알람을 끄려면 공부해야 한다! AI 퀴즈 + 모션 미션 기반 스마트 알람 앱

---

## 📱 소개

**Alarm Study**는 단순히 알람을 끄는 것이 아니라, 설정한 시험 범위의 문제를 풀어야 알람이 꺼지는 학습 유도형 알람 앱입니다.  
문제를 일정 비율 이상 틀리면 모션 감지 미션까지 수행해야 하므로, 확실한 기상과 학습 효과를 동시에 잡을 수 있습니다.

---

## ✨ 주요 기능

| 기능 | 설명 |
|------|------|
| 🏠 홈 화면 | 설정된 알람 목록 확인 및 관리 |
| ➕ 알람 추가 | 시간, 시험 범위, 미션 난이도 설정 |
| 🧠 AI 퀴즈 미션 | Gemini API 기반으로 시험 범위에 맞는 문제 자동 생성 |
| 🏃 모션 감지 미션 | 퀴즈를 일정 비율 이상 틀리면 모션 API 기반 신체 미션 수행 |

---

## 🖥️ 화면 구성

```
1. 홈 화면       — 알람 목록, ON/OFF 토글
2. 알람 추가     — 시간 설정, 시험 범위 입력
3. 퀴즈 미션     — AI가 생성한 문제 풀기 (알람 해제 조건)
4. 모션 미션     — 오답률 초과 시 모션 감지 미션 수행
```

---

## 🛠️ 기술 스택

| 분류 | 기술 |
|------|------|
| Frontend | Flutter (Dart) |
| AI 문제 생성 | Gemini API |
| 모션 감지 | Motion Detection API |
| 로컬 DB | Room DB / SQLite |
| 아키텍처 | MVVM |

---

## 👥 팀원

| 이름 | 역할 |
|이용욱|------|
|박건석|  |
|진유하|  |
|윤재영|  |

> 팀원 정보를 위 표에 직접 입력해주세요.

---

## 📁 프로젝트 구조

```
lib/
├── models/         # 데이터 모델
├── viewmodels/     # MVVM ViewModel
├── views/          # UI 화면
│   ├── home/
│   ├── alarm_add/
│   ├── quiz_mission/
│   └── motion_mission/
├── services/       # Gemini API, 모션 API 연동
└── data/           # Room DB / SQLite 연동
```

---

## 🚀 시작하기

```bash
# 저장소 클론
git clone https://github.com/YOUR_REPO_URL.git

# 패키지 설치
flutter pub get

# 앱 실행
flutter run
```

> `.env` 파일에 Gemini API Key를 설정해야 합니다.

```
GEMINI_API_KEY=your_api_key_here
```
