"""SQLAlchemy ORM models for the TY system — 6 tables in 'ty' schema.

Uses portable types (String for UUID, JSON) so tests can run on SQLite.
In production with PostgreSQL, the 'ty' schema is created by Alembic migrations.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.types import JSON, TypeDecorator
from sqlalchemy.orm import DeclarativeBase, relationship


class UUIDString(TypeDecorator):
    """Store UUIDs — uses native UUID on PostgreSQL, String(36) on SQLite."""
    impl = String(36)
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(PG_UUID(as_uuid=True))
        return dialect.type_descriptor(String(36))

    def process_bind_param(self, value, dialect):
        if value is not None:
            if dialect.name == "postgresql":
                return uuid.UUID(str(value)) if not isinstance(value, uuid.UUID) else value
            return str(value)
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            return uuid.UUID(str(value)) if not isinstance(value, uuid.UUID) else value
        return value


class Base(DeclarativeBase):
    pass


class Market(Base):
    __tablename__ = "markets"

    id = Column(UUIDString(), primary_key=True, default=uuid.uuid4)
    symbol = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(200), nullable=False)
    market_type = Column(String(30), nullable=False)
    source = Column(String(50), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    snapshots = relationship("MarketSnapshot", back_populates="market", lazy="selectin")
    judgments = relationship("Judgment", back_populates="market", lazy="selectin")


class MarketSnapshot(Base):
    __tablename__ = "market_snapshots"
    __table_args__ = (
        Index("ix_market_snapshots_market_captured", "market_id", "captured_at"),
    )

    id = Column(UUIDString(), primary_key=True, default=uuid.uuid4)
    market_id = Column(UUIDString(), ForeignKey("markets.id"), nullable=False)
    price = Column(Float, nullable=True)
    volume = Column(Float, nullable=True)
    change_pct = Column(Float, nullable=True)
    raw_data = Column(JSON, nullable=True)
    captured_at = Column(DateTime, default=datetime.utcnow)

    market = relationship("Market", back_populates="snapshots", lazy="selectin")


class Judgment(Base):
    __tablename__ = "judgments"
    __table_args__ = (
        Index("ix_judgments_market_created", "market_id", "created_at"),
    )

    id = Column(UUIDString(), primary_key=True, default=uuid.uuid4)
    market_id = Column(UUIDString(), ForeignKey("markets.id"), nullable=False)
    snapshot_id = Column(UUIDString(), ForeignKey("market_snapshots.id"), nullable=True)
    direction = Column(String(10), nullable=False)  # up/down/flat
    confidence = Column(String(10), nullable=False)  # high/medium/low
    confidence_score = Column(Float, nullable=False, default=0.5)
    rational_price = Column(Float, nullable=True)
    deviation_pct = Column(Float, nullable=True)
    reasoning = Column(Text, nullable=True)
    model_votes = Column(JSON, nullable=True)
    quality_score = Column(Float, nullable=True)
    up_probability = Column(Float, nullable=True)    # R13: probability for up
    down_probability = Column(Float, nullable=True)  # R13: probability for down
    flat_probability = Column(Float, nullable=True)  # R13: probability for flat
    bias_flags = Column(JSON, nullable=True)  # e.g. [{"type":"momentum","label":"...","detail":"..."}]
    is_low_confidence = Column(Boolean, default=False)  # L4: 低信心预测标记
    regime = Column(JSON, nullable=True)  # L2: market regime {regime, description, color}
    horizon_hours = Column(Integer, default=4)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    market = relationship("Market", back_populates="judgments", lazy="selectin")
    snapshot = relationship("MarketSnapshot", lazy="selectin")
    settlement = relationship("Settlement", back_populates="judgment", uselist=False, lazy="selectin")


class Settlement(Base):
    __tablename__ = "settlements"
    __table_args__ = (
        Index("ix_settlements_judgment_id", "judgment_id"),
    )

    id = Column(UUIDString(), primary_key=True, default=uuid.uuid4)
    judgment_id = Column(UUIDString(), ForeignKey("judgments.id"), unique=True, nullable=False)
    actual_price = Column(Float, nullable=True)
    actual_direction = Column(String(10), nullable=True)
    is_correct = Column(Boolean, nullable=True)
    brier_score = Column(Float, nullable=True)  # R14: probability calibration score (lower=better)
    settled_at = Column(DateTime, default=datetime.utcnow)

    judgment = relationship("Judgment", back_populates="settlement", lazy="selectin")


class AccuracyStat(Base):
    __tablename__ = "accuracy_stats"
    __table_args__ = (
        Index("ix_accuracy_stats_type_period_calc", "market_type", "period", "calculated_at"),
    )

    id = Column(UUIDString(), primary_key=True, default=uuid.uuid4)
    market_type = Column(String(30), nullable=False)
    period = Column(String(20), nullable=False)  # e.g. "7d", "30d", "all"
    total_judgments = Column(Integer, default=0)
    correct_judgments = Column(Integer, default=0)
    accuracy_pct = Column(Float, default=0.0)
    calibration_err = Column(Float, default=0.0)
    high_conf_accuracy = Column(Float, nullable=True)
    medium_conf_accuracy = Column(Float, nullable=True)
    low_conf_accuracy = Column(Float, nullable=True)
    calculated_at = Column(DateTime, default=datetime.utcnow)


class Plugin(Base):
    __tablename__ = "plugins"

    id = Column(UUIDString(), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), unique=True, nullable=False)
    display_name = Column(String(200), nullable=False)
    plugin_type = Column(String(30), nullable=False)
    version = Column(String(20), default="1.0.0")
    is_active = Column(Boolean, default=True)
    config = Column(JSON, nullable=True)
    registered_at = Column(DateTime, default=datetime.utcnow)
