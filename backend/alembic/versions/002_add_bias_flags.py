"""002_add_bias_flags — Add bias_flags JSON column to judgments table.

Revision ID: 002_add_bias_flags
Revises: 001_initial
Create Date: 2026-04-01
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "002_add_bias_flags"
down_revision = "001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "judgments",
        sa.Column("bias_flags", postgresql.JSONB, nullable=True),
        schema="ty",
    )


def downgrade() -> None:
    op.drop_column("judgments", "bias_flags", schema="ty")
