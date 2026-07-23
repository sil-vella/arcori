FROM python:3.12-slim-bookworm

WORKDIR /app

COPY requirements.txt gunicorn.conf.py alembic.ini ./
COPY alembic ./alembic
COPY entrypoint.sh entrypoint.dev.sh ./
RUN chmod +x entrypoint.sh entrypoint.dev.sh && pip install --no-cache-dir -r requirements.txt

COPY bin ./bin

ENV PORT=8000

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"

CMD ["./entrypoint.sh"]
