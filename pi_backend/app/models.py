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
    