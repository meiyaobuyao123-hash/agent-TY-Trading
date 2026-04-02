"""Configuration via Pydantic Settings — reads from .env or environment."""

from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── Database ──
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/finance_nav_db"
    DB_SCHEMA: str = "ty"

    # ── Redis ──
    REDIS_URL: str = "redis://localhost:6379/0"

    # ── Server ──
    PORT: int = 8003
    DEBUG: bool = False
    CORS_ORIGINS: list[str] = ["*"]

    # ── API Keys (AI models) ──
    ANTHROPIC_API_KEY: str = ""
    OPENAI_API_KEY: str = ""
    GOOGLE_API_KEY: str = ""
    DEEPSEEK_API_KEY: str = ""

    # ── API Keys (data sources) ──
    FRED_API_KEY: str = ""

    # ── API Key for trigger endpoint ──
    API_KEY: str = "ty-2026-secret-key"

    # ── Scheduler ──
    SCHEDULER_ENABLED: bool = True

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "extra": "ignore"}


settings = Settings()
