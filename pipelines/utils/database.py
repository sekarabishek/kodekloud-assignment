"""
Database connection utilities for the KodeKloud data pipeline.
Provides helper functions for connecting to PostgreSQL.
"""

import os
from typing import Optional
from contextlib import contextmanager

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    psycopg2 = None


def get_connection_string(
    host: str = "localhost",
    port: int = 5432,
    user: str = "assignment_user",
    password: str = "assignment_password",
    dbname: str = "assignment_db"
) -> str:
    """
    Build a PostgreSQL connection string.

    Args:
        host: Database host.
        port: Database port.
        user: Database user.
        password: Database password.
        dbname: Database name.

    Returns:
        PostgreSQL connection string.
    """
    return f"postgresql://{user}:{password}@{host}:{port}/{dbname}"


@contextmanager
def get_connection(
    host: Optional[str] = None,
    port: Optional[int] = None,
    user: Optional[str] = None,
    password: Optional[str] = None,
    dbname: Optional[str] = None
):
    """
    Context manager for PostgreSQL connections.
    Reads from environment variables if parameters are not provided.

    Usage:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")

    Args:
        host: Database host (default: env DB_HOST or localhost).
        port: Database port (default: env DB_PORT or 5432).
        user: Database user (default: env DB_USER or assignment_user).
        password: Database password (default: env DB_PASSWORD or assignment_password).
        dbname: Database name (default: env DB_NAME or assignment_db).

    Yields:
        psycopg2 connection object.
    """
    if psycopg2 is None:
        raise ImportError("psycopg2 is not installed. Run: pip install psycopg2-binary")

    conn = psycopg2.connect(
        host=host or os.getenv("DB_HOST", "localhost"),
        port=port or int(os.getenv("DB_PORT", "5432")),
        user=user or os.getenv("DB_USER", "assignment_user"),
        password=password or os.getenv("DB_PASSWORD", "assignment_password"),
        dbname=dbname or os.getenv("DB_NAME", "assignment_db"),
    )
    try:
        yield conn
    finally:
        conn.close()


def run_query(query: str, params: Optional[tuple] = None) -> list:
    """
    Execute a query and return results as a list of dictionaries.

    Args:
        query: SQL query string.
        params: Optional query parameters.

    Returns:
        List of dictionaries representing rows.
    """
    with get_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            return cur.fetchall()
