import asyncio
import os

import httpx

from .hardware import ToolNotFoundError
from .models import ToolTelemetry


class RemotePiHardware:
    """Communicates with Raspberry Pi gas controllers over HTTP."""

    def __init__(
        self,
        *,
        controller_url: str | None = None,
        tool_count: int = 6,
    ) -> None:
        configured_url = controller_url or os.getenv(
            "GAS_PI_CONTROLLER_URL",
            "http://127.0.0.1:9000",
        )

        self._controller_url = configured_url.rstrip("/")
        self._tool_count = tool_count

        self._timeout = httpx.Timeout(
            connect=2.0,
            read=3.0,
            write=3.0,
            pool=3.0,
        )

    async def read_all(self) -> list[ToolTelemetry]:
        tools = []

        async with httpx.AsyncClient(
            timeout=self._timeout,
        ) as client:
            for tool_id in range(1, self._tool_count + 1):
                telemetry = await self._read_tool(
                    client,
                    tool_id,
                )

                tools.append(telemetry)

        return tools

    async def set_valve_position(
        self,
        tool_id: int,
        requested_percent: float,
    ) -> ToolTelemetry:
        self._validate_tool_id(tool_id)

        async with httpx.AsyncClient(
            timeout=self._timeout,
        ) as client:
            response = await client.post(
                f"{self._controller_url}/tools/{tool_id}/valve",
                json={
                    "requested_valve_percent": requested_percent,
                },
            )

            response.raise_for_status()

            return ToolTelemetry.model_validate(
                response.json(),
            )

    async def close_valve(
        self,
        tool_id: int,
    ) -> ToolTelemetry:
        self._validate_tool_id(tool_id)

        async with httpx.AsyncClient(
            timeout=self._timeout,
        ) as client:
            response = await client.post(
                f"{self._controller_url}/tools/{tool_id}/close",
            )

            response.raise_for_status()

            return ToolTelemetry.model_validate(
                response.json(),
            )

    async def close_all(
        self,
    ) -> list[ToolTelemetry]:
        async with httpx.AsyncClient(
            timeout=self._timeout,
        ) as client:
            response = await client.post(
                f"{self._controller_url}/close-all",
            )

            response.raise_for_status()

            return [
                ToolTelemetry.model_validate(item)
                for item in response.json()
            ]

    async def _read_tool(
        self,
        client: httpx.AsyncClient,
        tool_id: int,
    ) -> ToolTelemetry:
        response = await client.get(
            f"{self._controller_url}/tools/{tool_id}",
        )

        if response.status_code == 404:
            raise ToolNotFoundError(
                f"Tool {tool_id} was not found.",
            )

        response.raise_for_status()

        return ToolTelemetry.model_validate(
            response.json(),
        )

    def _validate_tool_id(
        self,
        tool_id: int,
    ) -> None:
        if tool_id < 1 or tool_id > self._tool_count:
            raise ToolNotFoundError(
                f"Tool {tool_id} was not found.",
            )
            