from datetime import datetime, timezone

from pydantic import BaseModel, Field


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ToolTelemetry(BaseModel):
    tool_id: int
    name: str

    requested_valve_percent: float = Field(ge=0, le=100)
    actual_valve_percent: float = Field(ge=0, le=100)
    measured_flow_cfh: float = Field(ge=0)

    connected: bool
    fault: str | None = None
    updated_at: datetime = Field(default_factory=utc_now)


class SetValveRequest(BaseModel):
    requested_valve_percent: float = Field(ge=0, le=100)
    operator_id: str = Field(min_length=1, max_length=64)


class CloseValveRequest(BaseModel):
    operator_id: str = Field(min_length=1, max_length=64)


class CommandAuditEntry(BaseModel):
    id: int = Field(ge=1)
    timestamp: datetime
    operator_id: str
    action: str
    tool_id: int | None = Field(default=None, ge=1)
    requested_valve_percent: float | None = Field(
        default=None,
        ge=0,
        le=100,
    )
    success: bool
    detail: str
    