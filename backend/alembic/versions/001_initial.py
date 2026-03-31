"""001_initial — Create all 6 tables in the ty schema.

Revision ID: 001_initial
Revises:
Create Date: 2026-03-31
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create schema
    op.execute("CREATE SCHEMA IF NOT EXISTS ty")

    # markets
    op.create_table(
        "markets",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("symbol", sa.String(50), unique=True, nullable=False, index=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("market_type", sa.String(30), nullable=False),
        sa.Column("source", sa.String(50), nullable=False),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("created_at", sa.DateTime(), default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), default=sa.func.now()),
        schema="ty",
    )

    # market_snapshots
    op.create_table(
        "market_snapshots",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("market_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ty.markets.id"), nullable=False),
        sa.Column("price", sa.Float(), nullable=True),
        sa.Column("volume", sa.Float(), nullable=True),
        sa.Column("change_pct", sa.Float(), nullable=True),
        sa.Column("raw_data", postgresql.JSON(), nullable=True),
        sa.Column("captured_at", sa.DateTime(), default=sa.func.now()),
        schema="ty",
    )

    # judgments
    op.create_table(
        "judgments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("market_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ty.markets.id"), nullable=False),
        sa.Column("snapshot_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ty.market_snapshots.id"), nullable=True),
        sa.Column("direction", sa.String(10), nullable=False),
        sa.Column("confidence", sa.String(10), nullable=False),
        sa.Column("confidence_score", sa.Float(), nullable=False, default=0.5),
        sa.Column("rational_price", sa.Float(), nullable=True),
        sa.Column("deviation_pct", sa.Float(), nullable=True),
        sa.Column("reasoning", sa.Text(), nullable=True),
        sa.Column("model_votes", postgresql.JSON(), nullable=True),
        sa.Column("horizon_hours", sa.Integer(), default=4),
        sa.Column("expires_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), default=sa.func.now()),
        schema="ty",
    )

    # settlements
    op.create_table(
        "settlements",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("judgment_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ty.judgments.id"), unique=True, nullable=False),
        sa.Column("actual_price", sa.Float(), nullable=True),
        sa.Column("actual_direction", sa.String(10), nullable=True),
        sa.Column("is_correct", sa.Boolean(), nullable=True),
        sa.Column("settled_at", sa.DateTime(), default=sa.func.now()),
        schema="ty",
    )

    # accuracy_stats
    op.create_table(
        "accuracy_stats",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("market_type", sa.String(30), nullable=False),
        sa.Column("period", sa.String(20), nullable=False),
        sa.Column("total_judgments", sa.Integer(), default=0),
        sa.Column("correct_judgments", sa.Integer(), default=0),
        sa.Column("accuracy_pct", sa.Float(), default=0.0),
        sa.Column("calibration_err", sa.Float(), default=0.0),
        sa.Column("high_conf_accuracy", sa.Float(), nullable=True),
        sa.Column("medium_conf_accuracy", sa.Float(), nullable=True),
        sa.Column("low_conf_accuracy", sa.Float(), nullable=True),
        sa.Column("calculated_at", sa.DateTime(), default=sa.func.now()),
        schema="ty",
    )

    # plugins
    op.create_table(
        "plugins",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(100), unique=True, nullable=False),
        sa.Column("display_name", sa.String(200), nullable=False),
        sa.Column("plugin_type", sa.String(30), nullable=False),
        sa.Column("version", sa.String(20), default="1.0.0"),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("config", postgresql.JSON(), nullable=True),
        sa.Column("registered_at", sa.DateTime(), default=sa.func.now()),
        schema="ty",
    )

    # Seed initial markets
    op.execute("""
        INSERT INTO ty.markets (id, symbol, name, market_type, source, is_active, created_at, updated_at) VALUES
        (gen_random_uuid(), 'BTC-USD', 'Bitcoin', 'crypto', 'binance', true, now(), now()),
        (gen_random_uuid(), 'ETH-USD', 'Ethereum', 'crypto', 'binance', true, now(), now()),
        (gen_random_uuid(), '600519', 'Kweichow Moutai (贵州茅台)', 'cn-equities', 'akshare', true, now(), now()),
        (gen_random_uuid(), '000001', 'Shanghai Composite Index (上证指数)', 'global-indices', 'akshare', true, now(), now()),
        (gen_random_uuid(), 'USD/CNY', 'US Dollar / Chinese Yuan', 'forex', 'frankfurter', true, now(), now()),
        (gen_random_uuid(), 'EUR/USD', 'Euro / US Dollar', 'forex', 'frankfurter', true, now(), now()),
        (gen_random_uuid(), 'US-GDP', 'US Gross Domestic Product', 'macro', 'fred', true, now(), now()),
        (gen_random_uuid(), 'US-CPI', 'US Consumer Price Index', 'macro', 'fred', true, now(), now())
        ON CONFLICT (symbol) DO NOTHING;
    """)


def downgrade() -> None:
    op.drop_table("plugins", schema="ty")
    op.drop_table("accuracy_stats", schema="ty")
    op.drop_table("settlements", schema="ty")
    op.drop_table("judgments", schema="ty")
    op.drop_table("market_snapshots", schema="ty")
    op.drop_table("markets", schema="ty")
    op.execute("DROP SCHEMA IF EXISTS ty")
