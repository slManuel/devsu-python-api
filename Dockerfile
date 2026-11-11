# Alpine keeps the runtime image small; the digest makes the base reproducible.
FROM python:3.11-alpine3.24@sha256:bb1d70c1df30d8ee1e05214dbe82d6cdfd29833c1f47ce917f20991aca93acaa AS build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DJANGO_SETTINGS_MODULE=demo.settings

WORKDIR /app

RUN addgroup -S -g 10001 app \
    && adduser -S -D -H -u 10001 -G app -s /sbin/nologin app

RUN apk add --no-cache zlib=1.4-r0

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir --upgrade pip==26.3 \
    && python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip check \
    && python -m pip uninstall --yes setuptools wheel packaging \
    && python -m pip uninstall --yes pip \
    && rm -rf /usr/local/lib/python3.11/ensurepip /usr/local/lib/python3.11/venv

COPY --chown=app:app . .

FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS runtime

RUN apk add --no-cache \
    ca-certificates \
    gdbm \
    keyutils-libs \
    krb5-conf \
    krb5-libs=1.22.3-r0 \
    libbz2 \
    libcom_err \
    libcrypto3 \
    libffi \
    libintl \
    libncursesw \
    libnsl \
    libpanelw \
    libssl3 \
    libtirpc \
    libuuid \
    libverto \
    readline \
    sqlite-libs \
    xz-libs \
    zlib=1.4-r0

COPY --from=build /usr/local /usr/local
COPY --from=build --chown=10001:10001 /app /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=demo.settings \
    PATH=/usr/local/bin:$PATH

WORKDIR /app

RUN addgroup -S -g 10001 app \
    && adduser -S -D -H -u 10001 -G app -s /sbin/nologin app

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz/', timeout=2)"]

CMD ["gunicorn", "demo.wsgi:application", "--bind=0.0.0.0:8000", "--workers=2", "--access-logfile=-", "--error-logfile=-", "--timeout=30", "--no-control-socket"]
