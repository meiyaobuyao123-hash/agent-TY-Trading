"""003_confidence_history_and_priorities — Add confidence_history and market_priorities tables.

Revision ID: 003_confidence_history
Revises: 002_add_bias_flags
Create Date: 2026-04-01
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "003_confidence_history"
down_revision = "002_add_bias_flags"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Confidence history table
    op.create_table(
        "confidence_history",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("market_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ty.markets.id"), nullable=False),
        sa.Column("confidence_score", sa.Float, nullable=False),
        sa.Column("direction", sa.String(10), nullable=False),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
        schema="ty",
    )
    op.create_index(
        "ix_confidence_history_market_created",
        "confidence_history",
        ["market_id", "created_at"],
        schema="ty",
    )

    # Market priorities table
    op.create_table(
        "market_priorities",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("market_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ty.markets.id"), unique=True, nullable=False),
        sa.Column("priority_score", sa.Float, server_default="50.0"),
        sa.Column("accuracy_factor", sa.Float, server_default="0.0"),
        sa.Column("bias_factor", sa.Float, server_default="0.0"),
        sa.Column("settlement_factor", sa.Float, server_default="0.0"),
        sa.Column("updated_at", sa.DateTime, server_default=sa.func.now()),
        schema="ty",
    )
    op.create_index(
        "ix_market_priorities_score",
        "market_priorities",
        ["priority_score"],
        schema="ty",
    )


def downgrade() -> None:
    op.drop_table("market_priorities", schema="ty")
    op.drop_table("confidence_history", schema="ty")
