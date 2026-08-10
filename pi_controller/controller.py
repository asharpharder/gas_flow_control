from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


app = FastAPI(
    title="Gas Controller",
    version="0.1.0",
)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ControllerTelemetry(BaseModel):
    tool_id: int
    name: str
    gas_type: str
    cylinder_pressure_psi: float = Field(ge=0)
    requested_valve_percent: float = Field(ge=0, le=100)
    actual_valve_percent: float = Field(ge=0, le=100)
    measured_flow_cfh: float = Field(ge=0)
    target_flow_cfh: float = Field(ge=0)
    minimum_flow_cfh: float = Field(ge=0)
    maximum_flow_cfh: float = Field(ge=0)
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


tools: dict[int, ControllerTelemetry] = {}

for index in range(6):
    tool_id = index + 1
    target = targets[index]

    tools[tool_id] = ControllerTelemetry(
        tool_id=tool_id,
        name=f"Welding Tool {tool_id}",
        gas_type=gas_types[index],
        cylinder_pressure_psi=pressures[index],
        requested_valve_percent=0,
        actual_valve_percent=0,
        measured_flow_cfh=0,
        target_flow_cfh=target,
        minimum_flow_cfh=max(0, target - 3),
        maximum_flow_cfh=target + 3,
        connected=True,
        fault=None,
        updated_at=utc_now(),
    )


def get_tool(tool_id: int) -> ControllerTelemetry:
    tool = tools.get(tool_id)

    if tool is None:
        raise HTTPException(
            status_code=404,
            detail=f"Tool {tool_id} was not found.",
        )

    return tool


@app.get("/health")
def health():
    return {
        "ok": True,
        "controller": "fake-pi",
        "tool_count": len(tools),
    }


@app.get(
    "/tools/{tool_id}",
    response_model=ControllerTelemetry,
)
def read_tool(tool_id: int):
    return get_tool(tool_id)


@app.post(
    "/tools/{tool_id}/valve",
    response_model=ControllerTelemetry,
)
def set_valve(
    tool_id: int,
    command: ValveCommand,
):
    tool = get_tool(tool_id)

    requested = command.requested_valve_percent

    tool.requested_valve_percent = requested
    tool.actual_valve_percent = requested
    tool.measured_flow_cfh = round(
        requested * 0.40,
        1,
    )
    tool.updated_at = utc_now()

    return tool


@app.post(
    "/tools/{tool_id}/close",
    response_model=ControllerTelemetry,
)
def close_valve(tool_id: int):
    tool = get_tool(tool_id)

    tool.requested_valve_percent = 0
    tool.actual_valve_percent = 0
    tool.measured_flow_cfh = 0
    tool.updated_at = utc_now()

    return tool


@app.post(
    "/close-all",
    response_model=list[ControllerTelemetry],
)
def close_all():
    current_time = utc_now()

    for tool in tools.values():
        tool.requested_valve_percent = 0
        tool.actual_valve_percent = 0
        tool.measured_flow_cfh = 0
        tool.updated_at = current_time

    return list(tools.values())
    