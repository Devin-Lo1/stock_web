import hmac
import os

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


PROTECTED_PREFIXES = ("/api/v1/",)


def install_api_token_middleware(app: FastAPI) -> None:
    @app.middleware("http")
    async def api_token_middleware(request: Request, call_next):
        token = _configured_token()
        if not token or not _is_protected_path(request.url.path):
            return await call_next(request)

        provided_token = _read_request_token(request)
        if provided_token and hmac.compare_digest(provided_token, token):
            return await call_next(request)

        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={
                "detail": {
                    "code": "API_AUTH_REQUIRED",
                    "message": "API access token is required",
                    "detail": {},
                }
            },
            headers={"WWW-Authenticate": "Bearer"},
        )


def _configured_token() -> str:
    return os.getenv("API_ACCESS_TOKEN", "").strip()


def _is_protected_path(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in PROTECTED_PREFIXES)


def _read_request_token(request: Request) -> str:
    auth_header = request.headers.get("authorization", "").strip()
    scheme, _, credentials = auth_header.partition(" ")
    if scheme.lower() == "bearer" and credentials.strip():
        return credentials.strip()
    return request.headers.get("x-api-token", "").strip()
