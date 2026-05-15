from uuid import uuid4

from ..schemas import StrategyDefinition, StrategyDefinitionCreate
from ..db.core import _connect
from ..db.converters import _now, _row_to_strategy_definition, _strategy_definition_values


def list_strategy_definitions() -> list[StrategyDefinition]:
    with _connect() as connection:
        rows = connection.execute(
            """
            SELECT id, code, name, description, default_parameters,
                   created_at, updated_at
            FROM strategy_definitions
            ORDER BY code ASC
            """,
        ).fetchall()
    return [_row_to_strategy_definition(row) for row in rows]


def create_strategy_definition(
    payload: StrategyDefinitionCreate,
) -> StrategyDefinition:
    now = _now()
    strategy = StrategyDefinition(
        id=str(uuid4()),
        created_at=now,
        updated_at=now,
        **payload.model_dump(),
    )
    with _connect() as connection:
        connection.execute(
            """
            INSERT INTO strategy_definitions (
                id, code, name, description, default_parameters,
                created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(code) DO UPDATE SET
                name = excluded.name,
                description = excluded.description,
                default_parameters = excluded.default_parameters,
                updated_at = excluded.updated_at
            """,
            _strategy_definition_values(strategy),
        )
    return strategy
