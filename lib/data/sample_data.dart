// 앱 초기 목업 데이터 (기존 main.dart에 있던 것을 그대로 옮김 - 내용 변경 없음).
//
// TODO(실서버 연동): 아래 initialAlarms/initialMaterials는 목업 데이터.
// 나중에 백엔드 알람/학습자료 조회 API가 생기면, state/app_data.dart의 AppData가
// 이 목업 리스트 대신 API 응답으로 alarms/materials를 채우도록 바꾸면 됨
// (지금처럼 List<AlarmModel>/List<StudyMaterial> 형태만 맞춰서 넣어주면
// HomeScreen/AlarmListScreen/StudyMaterialScreen 등 화면 쪽은 수정 불필요).
import '../models/alarm_model.dart';
import '../models/study_material.dart';
import '../models/quiz_question.dart';

// ── 초기 샘플 알람 ──────────────────────────────────────────
final initialAlarms = [
  AlarmModel(
    id: 1, time: '06:30', label: '출근 준비',
    active: true, days: ['월', '화', '수', '목', '금'],
    quizSubject: '한국사', materialId: 1,
  ),
  AlarmModel(
    id: 2, time: '08:00', label: '주말 공부',
    active: false, days: ['토', '일'],
    quizSubject: '영어', materialId: 2,
  ),
];

// ── 초기 샘플 학습자료 (퀴즈 포함) ────────────────────────────
final initialMaterials = [
  StudyMaterial(
    id: 1, subject: '한국사', title: '조선시대 붕당정치',
    date: '2026-06-20',
    summary: '붕당정치는 16세기 중반 사림파 집권 이후 동인·서인으로 분열되었고, 이후 노론·소론·남인·북인으로 세분화되었습니다.',
    keyPoints: ['동인·서인 분열 (1575)', '예송논쟁으로 남인·서인 대립', '환국정치 - 숙종 시기 권력 교체'],
    quizCount: 3,
    quizQuestions: [
      QuizQuestion(
        question: '1575년 동인과 서인 분열의 직접적 원인은?',
        options: ['이조전랑 임명 문제', '임진왜란 발발', '예송논쟁', '인조반정'],
        correctIndex: 0,
      ),
      QuizQuestion(
        question: '예송논쟁에서 대립한 두 붕당은?',
        options: ['동인 vs 서인', '남인 vs 서인', '노론 vs 소론', '북인 vs 남인'],
        correctIndex: 1,
      ),
      QuizQuestion(
        question: '숙종 시기 권력이 붕당 간에 급격히 교체된 정치 형태를?',
        options: ['탕평책', '환국정치', '세도정치', '훈구정치'],
        correctIndex: 1,
      ),
    ],
  ),
  StudyMaterial(
    id: 2, subject: '영어', title: '관계대명사 완전정복',
    date: '2026-06-19',
    summary: '관계대명사는 두 문장을 연결하며 명사를 수식하는 절을 만든다. who·which·whose·that이 대표적이다.',
    keyPoints: ['who/whom - 사람', 'which - 사물', 'whose - 소유격'],
    quizCount: 3,
    quizQuestions: [
      QuizQuestion(
        question: '사람을 선행사로 받는 관계대명사는?',
        options: ['which', 'whose', 'who', 'that만 가능'],
        correctIndex: 2,
      ),
      QuizQuestion(
        question: '소유격 관계대명사는?',
        options: ['who', 'whom', 'which', 'whose'],
        correctIndex: 3,
      ),
      QuizQuestion(
        question: '사람과 사물 모두에 쓸 수 있는 관계대명사는?',
        options: ['who', 'which', 'whose', 'that'],
        correctIndex: 3,
      ),
    ],
  ),
];

// QuizQuestion은 더 이상 샘플로 사용하지 않음 — Gemini가 실시간 생성
final sampleQuiz = QuizQuestion(
  question: '(데모용) 이 문제는 사용되지 않습니다.',
  options: ['', '', '', ''],
  correctIndex: 0,
);
