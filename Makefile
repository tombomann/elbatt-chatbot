.PHONY: setup test lint run docker-build

setup:
\tpython -m venv .venv && . .venv/bin/activate && pip install -U pip -r requirements.txt

test:
\tpytest -q

lint:
\tflake8 . && black --check . && isort --check-only .

run:
\tuvicorn backend.main:app --reload --port 8000

docker-build:
\tdocker build -t elbatt-chatbot:dev .
