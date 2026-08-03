import os

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .hardware import SimulatedHardware
from .models import ToolTelemetry


API_TOKEN = os.getenv("GAS_APP_TOKEN", "local-simulation-token")

app = FastAPI(
    title="Gas Flow Control API",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1):[0-9]+$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

hardware = SimulatedHardware(tool_count=6)


def require_token(authorization: str | None) -> None:
    expected = f"Bearer {API_TOKEN}"

    if authorization != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/health")
async def health() -> dict[str, object]:
    return {
        "ok": True,
        "mode": "simulation",
    }


@app.get("/tools", response_model=list[ToolTelemetry])
async def get_tools(
    authorization: str | None = Header(default=None),
) -> list[ToolTelemetry]:
    require_token(authorization)
    return await hardware.read_all()
    