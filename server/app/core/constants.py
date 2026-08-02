# --- 업로드 제한 ---
MAX_FILE_SIZE_BYTES = 20 * 1024 * 1024      # 20MB (FILE_TOO_LARGE)
MAX_FILES_PER_SET = 5                        # SET_LIMIT_EXCEEDED
MAX_TOTAL_SIZE_PER_SET_BYTES = 50 * 1024 * 1024  # 50MB (SET_LIMIT_EXCEEDED)
PRESIGNED_URL_EXPIRES_SECONDS = 600

# --- AI 생성 ---
TOKEN_LIMIT_PER_SET = 500_000                # material_sets.tokens_used 비교 대상
GENERATION_BATCH_SIZE = 10                   # AI 호출 1회당 생성 문제 수
MAIN_MATERIAL_WEIGHT = 0.7                   # 메인 70 : 서브 30 (서브 없으면 100)
GENERATION_MAX_RETRY = 3                     # generation_jobs.retry_count 상한

# --- 버퍼 ---
BUFFER_TARGET_PER_SET = 20                   # 워커: target = 20 - 현재 버퍼 수
BUFFER_LOW_THRESHOLD = 10                    # 세션 시작 시 잔여 < 10 → buffer_low job

# --- 세션 ---
REQUIRED_CORRECT_COUNT = 3                   # 알람 해제에 필요한 정답 수 (팀 합의)

# --- 워커 ---
WORKER_POLL_INTERVAL_SECONDS = 10

# --- JWT ---
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 14