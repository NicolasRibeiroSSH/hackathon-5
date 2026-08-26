FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/root/.local/bin:$PATH"
COPY --from=builder /root/.local /root/.local
COPY . .
EXPOSE 8083
CMD ["gunicorn", "--bind", "0.0.0.0:8083", "--workers", "2", "--timeout", "60", "app:app"]
