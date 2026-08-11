from datetime import datetime, timezone


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ValveState:
    def __init__(
        self,
        *,
        tool_id: int,
        requested_percent: float = 0.0,
        actual_percent: float = 0.0,
        measured_flow_cfh: float = 0.0,
        connected: bool = True,
        fault: str | None = None,
    ) -> None:
        self.tool_id = tool_id
        self.requested_percent = requested_percent
        self.actual_percent = actual_percent
        self.measured_flow_cfh = measured_flow_cfh
        self.connected = connected
        self.fault = fault
        self.updated_at = utc_now()


class SimulatedValveHardware:
    """Temporary valve hardware implementation.

    This keeps the API working until a real motor driver and valve
    are connected to the Raspberry Pi.
    """

    def __init__(self, tool_count: int = 6) -> None:
        self._states = {
            tool_id: ValveState(
                tool_id=tool_id,
            )
            for tool_id in range(1, tool_count + 1)
        }

    def read(self, tool_id: int) -> ValveState:
        return self._get_state(tool_id)

    def set_position(
        self,
        tool_id: int,
        requested_percent: float,
    ) -> ValveState:
        if requested_percent < 0 or requested_percent > 100:
            raise ValueError(
                "Valve position must be between 0 and 100 percent."
            )

        state = self._get_state(tool_id)

        state.requested_percent = requested_percent

        # Temporary simulated behavior:
        # actual valve position immediately follows the request.
        state.actual_percent = requested_percent

        # Temporary simulated flow relationship.
        state.measured_flow_cfh = round(
            requested_percent * 0.40,
            1,
        )

        state.updated_at = utc_now()

        return state

    def close(self, tool_id: int) -> ValveState:
        return self.set_position(
            tool_id=tool_id,
            requested_percent=0.0,
        )

    def close_all(self) -> list[ValveState]:
        return [
            self.close(tool_id)
            for tool_id in sorted(self._states)
        ]

    def _get_state(self, tool_id: int) -> ValveState:
        state = self._states.get(tool_id)

        if state is None:
            raise KeyError(
                f"Tool {tool_id} was not found."
            )

        return state
        