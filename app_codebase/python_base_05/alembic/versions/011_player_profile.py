"""Alembic migration — Avari/player profile tables + admin testuser seed."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "011_player_profile"
down_revision = "010_design_standings"
branch_labels = None
depends_on = None

# Deterministic local test account (bcrypt via modules.auth.password_utils.hash_password).
TEST_USER_ID = uuid.UUID("a0000000-0000-4000-8000-000000000001")
TEST_EMAIL = "admin@reignofplay.com"
TEST_USERNAME = "admin"
# bcrypt of: qepiarcori1!
TEST_PASSWORD_HASH = (
    "$2b$12$B5YcO8kf7BqaDARKOS4n0eIdptvko6lc3VE9T71FNB4fKnpjEhZca"
)

STARTER_DESIGN_IDS = (
    "ANM-TIG-GEN001-0001",
    "ANM-WTI-GEN001-0002",
    "ANM-LIO-GEN001-0003",
    "ANM-BPA-GEN001-0004",
    "ANM-CHE-GEN001-0005",
    "ANM-LEO-GEN001-0006",
    "ANM-SNL-GEN001-0007",
    "ANM-JAG-GEN001-0008",
    "ANM-AWO-GEN001-0009",
    "ANM-GWO-GEN001-0010",
)
STARTER_SLAMMER_ID = "SLM-STR-GEN001-0001"
GENESIS_KIN_ID = "KIN-SIL202607092145-GEN001-0001"


def upgrade() -> None:
    op.create_table(
        "avari_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("display_name", sa.String(length=64), nullable=False),
        sa.Column(
            "primary_title",
            sa.String(length=64),
            nullable=False,
            server_default="Avari",
        ),
        sa.Column(
            "titles",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'[\"Avari\"]'::jsonb"),
        ),
        sa.Column("rank_xp", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("rank_level", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("rank_label", sa.String(length=64), nullable=True),
        sa.Column("gold_fragments", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("gold_caps", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("matches_played", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("wins", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("flips", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "onboarding_completed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "onboarding_kin_chosen",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "onboarding_genesis_created",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "onboarding_starter_granted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "onboarding_guided_practice_done",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "onboarding_intros_done",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "daily_login_streak",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column("daily_last_login_reward_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("daily_cache_claimed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "daily_no_miss_streak",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "notifications_push",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_avari_profiles_user_id"),
    )
    op.create_index("ix_avari_profiles_user_id", "avari_profiles", ["user_id"])

    op.create_table(
        "player_kin",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subtheme", sa.String(length=64), nullable=False),
        sa.Column("style", sa.String(length=64), nullable=False, server_default="Chibi"),
        sa.Column(
            "finish",
            sa.String(length=64),
            nullable=False,
            server_default="Standard",
        ),
        sa.Column("effect", sa.String(length=64), nullable=False, server_default="None"),
        sa.Column("genesis_design_id", sa.String(length=64), nullable=False),
        sa.Column("chosen_name", sa.String(length=64), nullable=False),
        sa.Column(
            "customization",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_player_kin_user_id"),
    )
    op.create_index("ix_player_kin_user_id", "player_kin", ["user_id"])

    op.create_table(
        "player_design_access",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False, server_default="starter"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "user_id",
            "design_id",
            name="uq_player_design_access_user_design",
        ),
    )
    op.create_index("ix_player_design_access_user_id", "player_design_access", ["user_id"])
    op.create_index(
        "ix_player_design_access_design_id",
        "player_design_access",
        ["design_id"],
    )

    op.create_table(
        "player_mastery",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("points", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "user_id",
            "design_id",
            "generation_number",
            name="uq_player_mastery_user_design_gen",
        ),
    )
    op.create_index("ix_player_mastery_user_id", "player_mastery", ["user_id"])
    op.create_index("ix_player_mastery_design_id", "player_mastery", ["design_id"])

    op.create_table(
        "player_slammers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column(
            "permanent",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("charges_remaining", sa.Integer(), nullable=True),
        sa.Column("source", sa.String(length=32), nullable=False, server_default="starter"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "design_id", name="uq_player_slammers_user_design"),
    )
    op.create_index("ix_player_slammers_user_id", "player_slammers", ["user_id"])
    op.create_index("ix_player_slammers_design_id", "player_slammers", ["design_id"])

    op.create_table(
        "player_trove",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False),
        sa.Column(
            "minted_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "legacy_title",
            sa.String(length=64),
            nullable=False,
            server_default="Legacy Owner",
        ),
        sa.Column(
            "creator_attributed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "user_id",
            "design_id",
            "generation_number",
            name="uq_player_trove_user_design_gen",
        ),
    )
    op.create_index("ix_player_trove_user_id", "player_trove", ["user_id"])
    op.create_index("ix_player_trove_design_id", "player_trove", ["design_id"])

    _seed_test_user()


def _seed_test_user() -> None:
    """Upsert admin@reignofplay.com with a complete starter Avari profile."""
    conn = op.get_bind()
    now = datetime.now(timezone.utc)

    existing = conn.execute(
        sa.text("SELECT id FROM users WHERE email = :email"),
        {"email": TEST_EMAIL},
    ).fetchone()

    if existing is not None:
        user_id = existing[0]
        conn.execute(
            sa.text(
                """
                UPDATE users
                SET username = :username,
                    password_hash = :password_hash,
                    is_guest = false,
                    email_verified_at = COALESCE(email_verified_at, :verified_at),
                    updated_at = :now
                WHERE id = :id
                """
            ),
            {
                "id": user_id,
                "username": TEST_USERNAME,
                "password_hash": TEST_PASSWORD_HASH,
                "verified_at": now,
                "now": now,
            },
        )
    else:
        # Prefer fixed id; fall back if collision (rare).
        taken = conn.execute(
            sa.text("SELECT 1 FROM users WHERE id = :id"),
            {"id": TEST_USER_ID},
        ).fetchone()
        user_id = TEST_USER_ID if taken is None else uuid.uuid4()
        conn.execute(
            sa.text(
                """
                INSERT INTO users (
                    id, username, email, password_hash, is_guest,
                    avatar_url, email_verified_at, created_at, updated_at
                ) VALUES (
                    :id, :username, :email, :password_hash, false,
                    NULL, :verified_at, :now, :now
                )
                """
            ),
            {
                "id": user_id,
                "username": TEST_USERNAME,
                "email": TEST_EMAIL,
                "password_hash": TEST_PASSWORD_HASH,
                "verified_at": now,
                "now": now,
            },
        )

    profile_exists = conn.execute(
        sa.text("SELECT 1 FROM avari_profiles WHERE user_id = :uid"),
        {"uid": user_id},
    ).fetchone()
    if profile_exists is None:
        conn.execute(
            sa.text(
                """
                INSERT INTO avari_profiles (
                    id, user_id, display_name, primary_title, titles,
                    rank_xp, rank_level, rank_label,
                    gold_fragments, gold_caps,
                    matches_played, wins, flips,
                    onboarding_completed, onboarding_kin_chosen,
                    onboarding_genesis_created, onboarding_starter_granted,
                    onboarding_guided_practice_done, onboarding_intros_done,
                    daily_login_streak, daily_last_login_reward_at,
                    daily_cache_claimed_at, daily_no_miss_streak,
                    notifications_push, notes, created_at, updated_at
                ) VALUES (
                    :id, :uid, :display_name, 'Avari', CAST(:titles AS jsonb),
                    0, 1, NULL,
                    0, 5,
                    0, 0, 0,
                    true, true, true, true, true, true,
                    0, NULL, NULL, 0,
                    true, :notes, :now, :now
                )
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": user_id,
                "display_name": "Admin",
                "titles": '["Avari"]',
                "notes": "Local test user seed (011_player_profile)",
                "now": now,
            },
        )
    else:
        conn.execute(
            sa.text(
                """
                UPDATE avari_profiles
                SET display_name = :display_name,
                    primary_title = 'Avari',
                    titles = CAST(:titles AS jsonb),
                    gold_caps = GREATEST(gold_caps, 5),
                    onboarding_completed = true,
                    onboarding_kin_chosen = true,
                    onboarding_genesis_created = true,
                    onboarding_starter_granted = true,
                    onboarding_guided_practice_done = true,
                    onboarding_intros_done = true,
                    notifications_push = true,
                    updated_at = :now
                WHERE user_id = :uid
                """
            ),
            {
                "uid": user_id,
                "display_name": "Admin",
                "titles": '["Avari"]',
                "now": now,
            },
        )

    kin_exists = conn.execute(
        sa.text("SELECT 1 FROM player_kin WHERE user_id = :uid"),
        {"uid": user_id},
    ).fetchone()
    if kin_exists is None:
        conn.execute(
            sa.text(
                """
                INSERT INTO player_kin (
                    id, user_id, subtheme, style, finish, effect,
                    genesis_design_id, chosen_name, customization,
                    created_at, updated_at
                ) VALUES (
                    :id, :uid, 'Entelairs', 'Chibi', 'Standard', 'None',
                    :genesis_id, 'Admin', CAST('{}' AS jsonb), :now, :now
                )
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": user_id,
                "genesis_id": GENESIS_KIN_ID,
                "now": now,
            },
        )

    for design_id in STARTER_DESIGN_IDS:
        conn.execute(
            sa.text(
                """
                INSERT INTO player_design_access (id, user_id, design_id, source, created_at)
                VALUES (:id, :uid, :design_id, 'starter', :now)
                ON CONFLICT ON CONSTRAINT uq_player_design_access_user_design DO NOTHING
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": user_id,
                "design_id": design_id,
                "now": now,
            },
        )

    conn.execute(
        sa.text(
            """
            INSERT INTO player_slammers (
                id, user_id, design_id, permanent, charges_remaining, source, created_at
            ) VALUES (
                :id, :uid, :design_id, true, NULL, 'starter', :now
            )
            ON CONFLICT ON CONSTRAINT uq_player_slammers_user_design DO NOTHING
            """
        ),
        {
            "id": uuid.uuid4(),
            "uid": user_id,
            "design_id": STARTER_SLAMMER_ID,
            "now": now,
        },
    )


def downgrade() -> None:
    op.drop_index("ix_player_trove_design_id", table_name="player_trove")
    op.drop_index("ix_player_trove_user_id", table_name="player_trove")
    op.drop_table("player_trove")

    op.drop_index("ix_player_slammers_design_id", table_name="player_slammers")
    op.drop_index("ix_player_slammers_user_id", table_name="player_slammers")
    op.drop_table("player_slammers")

    op.drop_index("ix_player_mastery_design_id", table_name="player_mastery")
    op.drop_index("ix_player_mastery_user_id", table_name="player_mastery")
    op.drop_table("player_mastery")

    op.drop_index("ix_player_design_access_design_id", table_name="player_design_access")
    op.drop_index("ix_player_design_access_user_id", table_name="player_design_access")
    op.drop_table("player_design_access")

    op.drop_index("ix_player_kin_user_id", table_name="player_kin")
    op.drop_table("player_kin")

    op.drop_index("ix_avari_profiles_user_id", table_name="avari_profiles")
    op.drop_table("avari_profiles")
