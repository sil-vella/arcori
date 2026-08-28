#!/usr/bin/env python3
# dash Ensure / renew Facebook, YouTube, TikTok tokens
"""Proactively renew marketing tokens and persist rotations into WFRUN_ENV_FILE.

- Facebook: extend Page token when expiry is near
- YouTube / TikTok: refresh access; write rotated refresh_token when returned
- invalid_grant → clear re-auth instructions (browser OAuth required)

Usage:
  wfrun → automation/marketing/ensure_platform_tokens.py
"""

from __future__ import annotations

import argparse
import json
import sys

from publish_common import require_wfrun
from token_renewal import ensure_marketing_tokens


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ensure FB/YT/TT tokens (auto-extend / refresh + persist)."
    )
    parser.add_argument(
        "--platforms",
        default="facebook,youtube,tiktok",
        help="Comma-separated platforms (default: facebook,youtube,tiktok).",
    )
    args = parser.parse_args()
    try:
        require_wfrun()
    except RuntimeError as exc:
        print(f"❌ {exc}", file=sys.stderr)
        return 1

    platforms = [p.strip() for p in args.platforms.split(",") if p.strip()]
    result = ensure_marketing_tokens(platforms=platforms)
    print(json.dumps(result, indent=2))
    if not result.get("ok"):
        print(
            "\n⚠️  One or more platforms need browser re-auth "
            "(youtube_oauth_get_refresh_token.py / tiktok_oauth_get_refresh_token.py / "
            "facebook_validate_page_token.py).",
            file=sys.stderr,
        )
        return 1
    print("\n✅ Tokens OK (rotated secrets written to WFRUN_ENV_FILE when needed).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
