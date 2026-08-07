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

        gas_types = [
            "Argon",
            "Argon",
            "75/25 Ar-CO2",
            "75/25 Ar-CO2",
            "Helium",
            "Nitrogen",
        ]

        starting_pressures = [
            1850.0,
            1725.0,
            1600.0,
            1450.0,
            1200.0,
            950.0,
        ]

        target_flows = [
            20.0,
            22.0,
            25.0,
            25.0,
            28.0,
            18.0,
        ]

        self._tools: dict[int, ToolTelemetry] = {}

        for tool_id in range(1, tool_count + 1):
            index = tool_id - 1

            target_flow = target_flows[index % len(target_flows)]

            self._tools[tool_id] = ToolTelemetry(
                tool_id=tool_id,
                name=f"Welding Tool {tool_id}",
                gas_type=gas_types[index % len(gas_types)],
                cylinder_pressure_psi=starting_pressures[
                    index % len(starting_pressures)
                ],
                requested_valve_percent=0.0,
                actual_valve_percent=0.0,
                measured_flow_cfh=0.0,
                target_flow_cfh=target_flow,
                minimum_flow_cfh=max(
                    0.0,
                    target_flow - 3.0,
                ),
                maximum_flow_cfh=target_flow + 3.0,
                connected=True,
                fault=None,
                updated_at=datetime.now(timezone.utc),
            )

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

            # Slowly reduce simulated cylinder pressure while gas is flowing.
            if tool.measured_flow_cfh > 0:
                pressure_drop = max(
                    0.5,
                    tool.measured_flow_cfh * 0.02,
                )

                tool.cylinder_pressure_psi = max(
                    0.0,
                    round(
                        tool.cylinder_pressure_psi - pressure_drop,
                        1,
                    ),
                )

            tool.updated_at = datetime.now(timezone.utc)

            return tool.model_copy(deep=True)

    async def close_valve(
        self,
        tool_id: int,
    ) -> ToolTelemetry:
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

    def _get_tool(
        self,
        tool_id: int,
    ) -> ToolTelemetry:
        """Return a tool or raise ToolNotFoundError."""

        tool = self._tools.get(tool_id)

        if tool is None:
            raise ToolNotFoundError(
                f"Tool {tool_id} was not found."
            )

        return tool
        