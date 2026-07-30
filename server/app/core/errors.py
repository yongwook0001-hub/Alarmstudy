class AppError(Exception):
    """공통 에러 응답 {"error_code": "SNAKE_CASE", "message": "..."}으로 변환되는 앱 레벨 예외."""

    def __init__(self, status_code: int, error_code: str, message: str) -> None:
        self.status_code = status_code
        self.error_code = error_code
        self.message = message
        super().__init__(message)
