from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from valve_hardware import SimulatedValveHardware


app = FastAPI(
    title="Gas Controller",
    version="0.2.0",
)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ControllerTelemetry(BaseModel):
    tool_id: int
    name: str
    gas_type: str

    cylinder_pressure_psi: float = Field(
        ge=0,
    )

    requested_valve_percent: float = Field(
        ge=0,
        le=100,
    )

    actual_valve_percent: float = Field(
        ge=0,
        le=100,
    )

    measured_flow_cfh: float = Field(
        ge=0,
    )

    target_flow_cfh: float = Field(
        ge=0,
    )

    minimum_flow_cfh: float = Field(
        ge=0,
    )

    maximum_flow_cfh: float = Field(
        ge=0,
    )

    connected: bool
    fault: str | None = None
    updated_at: datetime


class ValveCommand(BaseModel):
    requested_valve_percent: float = Field(
        ge=0,
        le=100,
    )


gas_types = [
    "Argon",
    "Argon",
    "75/25 Ar-CO2",
    "75/25 Ar-CO2",
    "Helium",
    "Nitrogen",
]

pressures = [
    1850.0,
    1725.0,
    1600.0,
    1450.0,
    1200.0,
    950.0,
]

targets = [
    20.0,
    22.0,
    25.0,
    25.0,
    28.0,
    18.0,
]


hardware = SimulatedValveHardware(
    tool_count=6,
)


def get_tool_configuration(
    tool_id: int,
) -> tuple[str, float, float]:
    index = tool_id - 1

    if index < 0 or index >= len(gas_types):
        raise HTTPException(
            status_code=404,
            detail=f"Tool {tool_id} was not found.",
        )

    return (
        gas_types[index],
        pressures[index],
        targets[index],
    )


def build_telemetry(
    tool_id: int,
) -> ControllerTelemetry:
    try:
        state = hardware.read(tool_id)
    except KeyError as error:
        raise HTTPException(
            status_code=404,
            detail=str(error),
        ) from error

    gas_type, pressure, target = get_tool_configuration(
        tool_id,
    )

    return ControllerTelemetry(
        tool_id=tool_id,
        name=f"Welding Tool {tool_id}",
        gas_type=gas_type,
        cylinder_pressure_psi=pressure,
        requested_valve_percent=(
            state.requested_percent
        ),
        actual_valve_percent=(
            state.actual_percent
        ),
        measured_flow_cfh=(
            state.measured_flow_cfh
        ),
        target_flow_cfh=target,
        minimum_flow_cfh=max(
            0.0,
            target - 3.0,
        ),
        maximum_flow_cfh=target + 3.0,
        connected=state.connected,
        fault=state.fault,
        updated_at=state.updated_at,
    )


@app.get("/health")
def health():
    return {
        "ok": True,
        "controller": "GasControlPi",
        "hardware": "simulated-valve",
        "tool_count": 6,
        "api_version": app.version,
    }


@app.get(
    "/tools/{tool_id}",
    response_model=ControllerTelemetry,
)
def read_tool(
    tool_id: int,
):
    return build_telemetry(
        tool_id,
    )


@app.post(
    "/tools/{tool_id}/valve",
    response_model=ControllerTelemetry,
)
def set_valve(
    tool_id: int,
    command: ValveCommand,
):
    try:
        hardware.set_position(
            tool_id=tool_id,
            requested_percent=(
                command.requested_valve_percent
            ),
        )
    except KeyError as error:
        raise HTTPException(
            status_code=404,
            detail=str(error),
        ) from error

    return build_telemetry(
        tool_id,
    )


@app.post(
    "/tools/{tool_id}/close",
    response_model=ControllerTelemetry,
)
def close_valve(
    tool_id: int,
):
    try:
        hardware.close(
            tool_id,
        )
    except KeyError as error:
        raise HTTPException(
            status_code=404,
            detail=str(error),
        ) from error

    return build_telemetry(
        tool_id,
    )


@app.post(
    "/close-all",
    response_model=list[ControllerTelemetry],
)
def close_all():
    hardware.close_all()

    return [
        build_telemetry(tool_id)
        for tool_id in range(1, 7)
    ]
    