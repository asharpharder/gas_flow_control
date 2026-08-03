from datetime import datetime, timezone

from .models import ToolTelemetry


SIMULATED_MAX_FLOW_CFH = 40.0


class ToolNotFoundError(Exception):
    pass


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

    def _find_tool(self, tool_id: int) -> ToolTelemetry:
        for tool in self._tools:
            if tool.tool_id == tool_id:
                return tool

        raise ToolNotFoundError(f"Tool {tool_id} was not found")

    async def read_all(self) -> list[ToolTelemetry]:
        current_time = datetime.now(timezone.utc)

        for tool in self._tools:
            tool.updated_at = current_time

        return [tool.model_copy(deep=True) for tool in self._tools]

    async def set_valve_position(
        self,
        tool_id: int,
        requested_percent: float,
    ) -> ToolTelemetry:
        tool = self._find_tool(tool_id)

        tool.requested_valve_percent = requested_percent
        tool.actual_valve_percent = requested_percent
        tool.measured_flow_cfh = round(
            SIMULATED_MAX_FLOW_CFH * requested_percent / 100,
            1,
        )
        tool.updated_at = datetime.now(timezone.utc)

        return tool.model_copy(deep=True)

    async def close_valve(self, tool_id: int) -> ToolTelemetry:
        return await self.set_valve_position(
            tool_id=tool_id,
            requested_percent=0,
        )      