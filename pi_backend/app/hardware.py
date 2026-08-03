import asyncio
from datetime import datetime, timezone

from .models import ToolTelemetry


class ToolNotFoundError(Exception):
    """Raised when a requested welding tool does not exist."""

    pass


class SimulatedHardware:
    """Simulates motorized needle valves until the real hardware is ready."""

    def __init__(self, tool_count: int = 6) -> None:
        self._lock = asyncio.Lock()

        self._tools: dict[int, ToolTelemetry] = {
            tool_id: ToolTelemetry(
                tool_id=tool_id,
                name=f"Welding Tool {tool_id}",
                requested_valve_percent=0.0,
                actual_valve_percent=0.0,
                measured_flow_cfh=0.0,
                connected=True,
                fault=None,
                updated_at=datetime.now(timezone.utc),
            )
            for tool_id in range(1, tool_count + 1)
        }

    async def read_all(self) -> list[ToolTelemetry]:
        """Return telemetry for all simulated welding tools."""

        async with self._lock:
            return [
                tool.model_copy(deep=True)
                for tool in self._tools.values()
            ]

    async def set_valve_position(
        self,
        tool_id: int,
        requested_percent: float,
    ) -> ToolTelemetry:
        """Set one valve between 0 and 100 percent open."""

        if requested_percent < 0 or requested_percent > 100:
            raise ValueError(
                "Valve position must be between 0 and 100 percent."
            )

        async with self._lock:
            tool = self._get_tool(tool_id)

            tool.requested_valve_percent = requested_percent
            tool.actual_valve_percent = requested_percent

            # Simulation assumption:
            # A 100% valve position produces approximately 40 CFH.
            tool.measured_flow_cfh = round(
                requested_percent * 0.40,
                1,
            )

            tool.updated_at = datetime.now(timezone.utc)

            return tool.model_copy(deep=True)

    async def close_valve(self, tool_id: int) -> ToolTelemetry:
        """Command one valve to the fully closed position."""

        return await self.set_valve_position(
            tool_id=tool_id,
            requested_percent=0.0,
        )

    async def close_all(self) -> list[ToolTelemetry]:
        """Command every valve to the fully closed position."""

        async with self._lock:
            current_time = datetime.now(timezone.utc)

            for tool in self._tools.values():
                tool.requested_valve_percent = 0.0
                tool.actual_valve_percent = 0.0
                tool.measured_flow_cfh = 0.0
                tool.updated_at = current_time

            return [
                tool.model_copy(deep=True)
                for tool in self._tools.values()
            ]

    def _get_tool(self, tool_id: int) -> ToolTelemetry:
        """Return a tool or raise ToolNotFoundError."""

        tool = self._tools.get(tool_id)

        if tool is None:
            raise ToolNotFoundError(
                f"Tool {tool_id} was not found."
            )

        return tool
        