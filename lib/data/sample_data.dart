// 더 이상 사용하지 않는 목업 데이터 파일.
//
// 실제 백엔드(/api/alarms, /api/sets) 연동으로 전환하면서 이 파일의 initialAlarms/
// initialMaterials/sampleQuiz는 어디서도 import하지 않는다 (lib/state/app_data.dart가
// 이제 AlarmsService/SetsService로 서버에서 직접 불러온다).
//
// 파일 자체를 지우고 싶었지만 샌드박스 권한 문제로 삭제가 안 돼서 내용만 비워뒀다 -
// 실제 로컬 터미널에서는 `rm lib/data/sample_data.dart`로 지우고
// `lib/data/` 폴더도 함께 정리해도 된다 (더 이상 이 폴더를 쓰는 곳이 없음).
