from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Application
    APP_NAME: str = "HumSukhan API"
    APP_VERSION: str = "1.1.0"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"

    # Database (from environment - no localhost default)
    DATABASE_URL: str = ""
    DATABASE_ECHO: bool = False

    # Authentication
    SECRET_KEY: str = ""
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Supabase
    SUPABASE_URL: Optional[str] = None
    SUPABASE_ANON_KEY: Optional[str] = None

    # CORS
    CORS_ORIGINS: list[str] = ["*"]

    # AI Services
    GEMINI_API_KEY: Optional[str] = None

    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60

    # Logging
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


settings = Settings()
