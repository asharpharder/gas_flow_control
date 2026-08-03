from datetime import datetime, timezone

from .models import ToolTelemetry


class SimulatedHardware:
    def __init__(self, tool_count: int = 6) -> None:
        self._tools = [
            ToolTelemetry(
                tool_id=tool_id,
                name=f"Welding Tool {tool_id}",
                requested_valve_percent=0,
                actual_valve_percent=0,
                measured_flow_cfh=0,
                connected=True,
            )
            for tool_id in range(1, tool_count + 1)
        ]

    async def read_all(self) -> list[ToolTelemetry]:
        current_time = datetime.now(timezone.utc)

        for tool in self._tools:
            tool.updated_at = current_time

        return [tool.model_copy(deep=True) for tool in self._tools]
        