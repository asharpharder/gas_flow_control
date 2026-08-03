import asyncio
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from .models import CommandAuditEntry


class CommandAuditStore:
    """Persistent SQLite storage for controller command history."""

    def __init__(self, database_path: Path | None = None) -> None:
        default_path = (
            Path(__file__).resolve().parent.parent
            / "data"
            / "command_audit.db"
        )

        self._database_path = database_path or default_path
        self._database_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        self._initialize_database()

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(
            self._database_path,
            timeout=5.0,
        )

    def _initialize_database(self) -> None:
        with self._connect() as connection:
            connection.execute("PRAGMA journal_mode=WAL")

            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS command_audit (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    operator_id TEXT NOT NULL,
                    action TEXT NOT NULL,
                    tool_id INTEGER,
                    requested_valve_percent REAL,
                    success INTEGER NOT NULL,
                    detail TEXT NOT NULL
                )
                """
            )

            connection.execute(
                """
                CREATE INDEX IF NOT EXISTS
                index_command_audit_timestamp
                ON command_audit(timestamp DESC)
                """
            )

            connection.commit()

    async def record(
        self,
        *,
        operator_id: str,
        action: str,
        tool_id: int | None,
        requested_valve_percent: float | None,
        success: bool,
        detail: str,
    ) -> CommandAuditEntry:
        return await asyncio.to_thread(
            self._record_sync,
            operator_id=operator_id,
            action=action,
            tool_id=tool_id,
            requested_valve_percent=requested_valve_percent,
            success=success,
            detail=detail,
        )

    def _record_sync(
        self,
        *,
        operator_id: str,
        action: str,
        tool_id: int | None,
        requested_valve_percent: float | None,
        success: bool,
        detail: str,
    ) -> CommandAuditEntry:
        timestamp = datetime.now(timezone.utc)

        with self._connect() as connection:
            cursor = connection.execute(
                """
                INSERT INTO command_audit (
                    timestamp,
                    operator_id,
                    action,
                    tool_id,
                    requested_valve_percent,
                    success,
                    detail
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    timestamp.isoformat(),
                    operator_id,
                    action,
                    tool_id,
                    requested_valve_percent,
                    int(success),
                    detail,
                ),
            )

            connection.commit()
            entry_id = int(cursor.lastrowid)

        return CommandAuditEntry(
            id=entry_id,
            timestamp=timestamp,
            operator_id=operator_id,
            action=action,
            tool_id=tool_id,
            requested_valve_percent=requested_valve_percent,
            success=success,
            detail=detail,
        )

    async def list_recent(
        self,
        limit: int,
    ) -> list[CommandAuditEntry]:
        return await asyncio.to_thread(
            self._list_recent_sync,
            limit,
        )

    def _list_recent_sync(
        self,
        limit: int,
    ) -> list[CommandAuditEntry]:
        with self._connect() as connection:
            connection.row_factory = sqlite3.Row

            rows = connection.execute(
                """
                SELECT
                    id,
                    timestamp,
                    operator_id,
                    action,
                    tool_id,
                    requested_valve_percent,
                    success,
                    detail
                FROM command_audit
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()

        return [
            CommandAuditEntry(
                id=row["id"],
                timestamp=datetime.fromisoformat(
                    row["timestamp"],
                ),
                operator_id=row["operator_id"],
                action=row["action"],
                tool_id=row["tool_id"],
                requested_valve_percent=(
                    row["requested_valve_percent"]
                ),
                success=bool(row["success"]),
                detail=row["detail"],
            )
            for row in rows
        ]