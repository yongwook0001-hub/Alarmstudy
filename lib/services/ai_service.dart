// 더 이상 사용하지 않는 서비스 파일.
//
// 예전에는 이 서비스가 서버의 레거시 엔드포인트(POST /summarize, /summarize/pdf -
// server/app/main.py 참고)를 호출해서 텍스트/PDF를 즉석으로 요약+퀴즈 3문제로
// 변환했었다. 실제 백엔드 설계(세트/자료/버퍼 문제 - server/app/api/sets.py,
// materials.py, sessions.py)로 전환하면서 이 즉석 요약 흐름은 더 이상 쓰지 않는다
// (지금은 lib/services/materials_service.dart가 PDF를 S3에 직접 업로드하고,
// 서버가 백그라운드에서 파싱/요약/문제생성을 한다).
//
// 파일 자체를 지우고 싶었지만 샌드박스 권한 문제로 삭제가 안 돼서 내용만 비워뒀다 -
// 실제 로컬 터미널에서는 `rm lib/services/ai_service.dart`,
// `rm lib/models/quiz_question.dart`로 지워도 된다 (더 이상 쓰는 곳이 없음).
//
// 참고: server/app/main.py의 /summarize, /summarize/pdf 엔드포인트 자체는 아직
// 서버 코드에 남아있다 - 백엔드 팀원과 상의해서 정리 여부를 결정하는 게 좋다.
