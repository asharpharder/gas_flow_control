import logging
import os

from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from .audit import CommandAuditStore
from .hardware import SimulatedHardware, ToolNotFoundError
from .remote_pi_hardware import RemotePiHardware
from .models import (
    CloseValveRequest,
    CommandAuditEntry,
    SetValveRequest,
    ToolTelemetry,
)


logger = logging.getLogger("uvicorn.error")


def _read_allowed_origins() -> list[str]:
    configured_origins = os.getenv(
        "GAS_ALLOWED_ORIGINS",
        "",
    )

    origins = {
        origin.strip().rstrip("/")
        for origin in configured_origins.split(",")
        if origin.strip()
    }

    origins.update(
        {
            "http://localhost",
            "http://127.0.0.1",
        }
    )

    return sorted(origins)


API_TOKEN = os.getenv(
    "GAS_APP_TOKEN",
    "local-simulation-token",
)

ALLOWED_ORIGINS = _read_allowed_origins()

app = FastAPI(
    title="Gas Flow Control API",
    version="0.4.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=(
        r"^http://(localhost|127\.0\.0\.1):[0-9]+$"
    ),
    allow_credentials=False,
    allow_methods=[
        "GET",
        "POST",
        "OPTIONS",
    ],
    allow_headers=[
        "Authorization",
        "Content-Type",
    ],
)


HARDWARE_MODE = os.getenv(
    "GAS_HARDWARE_MODE",
    "simulation",
).strip().lower()


def create_hardware():
    if HARDWARE_MODE == "simulation":
        logger.info("Gas hardware mode: simulation")
        return SimulatedHardware(tool_count=6)

    if HARDWARE_MODE == "remote_pi":
        logger.info("Gas hardware mode: remote_pi")
        return RemotePiHardware(tool_count=6)

    raise RuntimeError(
        "Unsupported GAS_HARDWARE_MODE: "
        f"{HARDWARE_MODE}",
    )


hardware = create_hardware()
audit_store = CommandAuditStore()


def require_token(authorization: str | None) -> None:
    expected = f"Bearer {API_TOKEN}"

    if authorization != expected:
        raise HTTPException(
            status_code=401,
            detail="Unauthorized",
        )


async def record_command(
    *,
    operator_id: str,
    action: str,
    tool_id: int | None,
    requested_valve_percent: float | None,
    success: bool,
    detail: str,
) -> None:
    try:
        await audit_store.record(
            operator_id=operator_id,
            action=action,
            tool_id=tool_id,
            requested_valve_percent=requested_valve_percent,
            success=success,
            detail=detail,
        )
    except Exception:
        logger.exception(
            "Unable to write command audit record."
        )


@app.get("/health")
async def health() -> dict[str, object]:
    return {
        "ok": True,
        "mode": HARDWARE_MODE,
        "audit_storage": "sqlite",
        "api_version": app.version,
    }


@app.get(
    "/tools",
    response_model=list[ToolTelemetry],
)
async def get_tools(
    authorization: str | None = Header(default=None),
) -> list[ToolTelemetry]:
    require_token(authorization)

    return await hardware.read_all()


@app.get(
    "/audit",
    response_model=list[CommandAuditEntry],
)
async def get_audit_history(
    limit: int = Query(
        default=100,
        ge=1,
        le=500,
    ),
    authorization: str | None = Header(default=None),
) -> list[CommandAuditEntry]:
    require_token(authorization)

    return await audit_store.list_recent(limit)


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

    try:
        telemetry = await hardware.set_valve_position(
            tool_id=tool_id,
            requested_percent=(
                request.requested_valve_percent
            ),
        )
    except ToolNotFoundError as error:
        await record_command(
            operator_id=request.operator_id,
            action="set_valve_position",
            tool_id=tool_id,
            requested_valve_percent=(
                request.requested_valve_percent
            ),
            success=False,
            detail=str(error),
        )

        raise HTTPException(
            status_code=404,
            detail=str(error),
        ) from error
    except Exception as error:
        await record_command(
            operator_id=request.operator_id,
            action="set_valve_position",
            tool_id=tool_id,
            requested_valve_percent=(
                request.requested_valve_percent
            ),
            success=False,
            detail=f"{type(error).__name__}: {error}",
        )

        logger.exception(
            "Valve-position command failed."
        )

        raise HTTPException(
            status_code=500,
            detail="Valve-position command failed.",
        ) from error

    await record_command(
        operator_id=request.operator_id,
        action="set_valve_position",
        tool_id=tool_id,
        requested_valve_percent=(
            request.requested_valve_percent
        ),
        success=True,
        detail="Valve-position command accepted.",
    )

    return telemetry


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

    try:
        telemetry = await hardware.close_valve(
            tool_id,
        )
    except ToolNotFoundError as error:
        await record_command(
            operator_id=request.operator_id,
            action="close_valve",
            tool_id=tool_id,
            requested_valve_percent=0.0,
            success=False,
            detail=str(error),
        )

        raise HTTPException(
            status_code=404,
            detail=str(error),
        ) from error
    except Exception as error:
        await record_command(
            operator_id=request.operator_id,
            action="close_valve",
            tool_id=tool_id,
            requested_valve_percent=0.0,
            success=False,
            detail=f"{type(error).__name__}: {error}",
        )

        logger.exception(
            "Close-valve command failed."
        )

        raise HTTPException(
            status_code=500,
            detail="Close-valve command failed.",
        ) from error

    await record_command(
        operator_id=request.operator_id,
        action="close_valve",
        tool_id=tool_id,
        requested_valve_percent=0.0,
        success=True,
        detail="Valve-close command accepted.",
    )

    return telemetry


@app.post(
    "/close-all",
    response_model=list[ToolTelemetry],
)
async def close_all(
    request: CloseValveRequest,
    authorization: str | None = Header(default=None),
) -> list[ToolTelemetry]:
    require_token(authorization)

    try:
        telemetry = await hardware.close_all()
    except Exception as error:
        await record_command(
            operator_id=request.operator_id,
            action="close_all",
            tool_id=None,
            requested_valve_percent=0.0,
            success=False,
            detail=f"{type(error).__name__}: {error}",
        )

        logger.exception(
            "Close-all command failed."
        )

        raise HTTPException(
            status_code=500,
            detail="Close-all command failed.",
        ) from error

    await record_command(
        operator_id=request.operator_id,
        action="close_all",
        tool_id=None,
        requested_valve_percent=0.0,
        success=True,
        detail="All valves commanded closed.",
    )

    return telemetry
    