import logging
import os

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .hardware import SimulatedHardware, ToolNotFoundError
from .models import CloseValveRequest, SetValveRequest, ToolTelemetry


logger = logging.getLogger(__name__)

API_TOKEN = os.getenv("GAS_APP_TOKEN", "local-simulation-token")

app = FastAPI(
    title="Gas Flow Control API",
    version="0.2.0",
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


@app.post(
    "/tools/{tool_id}/valve",
    response_model=ToolTelemetry,
)
async def set_valve_position(
    tool_id: int,
    request: SetValveRequest,
    authorization: str | None = Header(default=None),
) -> ToolTelemetry:
    require_token(authorization)

    logger.info(
        "Valve command: operator=%s tool=%s requested_percent=%s",
        request.operator_id,
        tool_id,
        request.requested_valve_percent,
    )

    try:
        return await hardware.set_valve_position(
            tool_id=tool_id,
            requested_percent=request.requested_valve_percent,
        )
    except ToolNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error

@app.post(
    "/tools/{tool_id}/close",
    response_model=ToolTelemetry,
)
async def close_valve(
    tool_id: int,
    request: CloseValveRequest,
    authorization: str | None = Header(default=None),
) -> ToolTelemetry:
    require_token(authorization)

    logger.info(
        "Close command: operator=%s tool=%s",
        request.operator_id,
        tool_id,
    )

    try:
        return await hardware.close_valve(tool_id)
    except ToolNotFoundError as error: 
        raise HTTPException(status_code=404, detail=str(error)) from error

@app.post("/close-all", response_model=list[ToolTelemetry])
async def close_all(
    authorization: str | None = Header(default=None),
) -> list[ToolTelemetry]:
    require_token(authorization)
    return await hardware.close_all()