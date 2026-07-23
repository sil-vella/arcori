"""Entry point — delegates to ``app_init`` (mirrors Dart ``app.dart``)."""

from app_init import start_app


def main() -> None:
    start_app()


if __name__ == "__main__":
    main()
