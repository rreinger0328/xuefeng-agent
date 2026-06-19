FROM python:3.10-slim

WORKDIR /app

# Copy application files
COPY server.py .
COPY admission_clean.db.gz .
COPY img_suit.png img_scifi.png ./

# Extract database during build (so the container starts instantly)
# The server.py would extract on first run, but doing it at build time
# avoids the 143MB extraction delay on every fresh container
RUN python -c "import gzip,shutil; gzip.open('admission_clean.db.gz','rb'); print('db.gz ready')" \
    && python -c "import gzip,shutil,sys; src=gzip.open('admission_clean.db.gz','rb'); dst=open('admission_clean.db','wb'); shutil.copyfileobj(src,dst); print('database extracted')" \
    && rm admission_clean.db.gz

# Verify the database was extracted
RUN python -c "import sqlite3,os; conn=sqlite3.connect('admission_clean.db'); print(f'DB rows: {conn.execute(\"SELECT COUNT(*) FROM admission\").fetchone()[0]}'); conn.close()"

EXPOSE 8765

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8765/ping')" || exit 1

CMD ["python", "server.py"]
