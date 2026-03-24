"""
Data quality check utilities for the KodeKloud data pipeline.
Provides reusable validation functions that can be run independently
or as part of the Airflow-orchestrated pipeline.
"""

import logging
from typing import Dict, List
from pipelines.utils.database import run_query

logger = logging.getLogger(__name__)


class DataQualityChecker:
    """
    Runs data quality checks against the analytics database.
    Results are logged and returned as a summary dictionary.
    """

    def __init__(self):
        self.results: List[Dict] = []

    def check_not_null(self, table: str, column: str) -> bool:
        """
        Check that a column has no null values.

        Args:
            table: Table name.
            column: Column name.

        Returns:
            True if check passes (no nulls found).
        """
        query = f"SELECT COUNT(*) as null_count FROM public.{table} WHERE {column} IS NULL"
        result = run_query(query)
        null_count = result[0]["null_count"]
        passed = null_count == 0

        self.results.append({
            "table": table,
            "check": f"not_null_{column}",
            "passed": passed,
            "details": f"{null_count} null values found"
        })

        if not passed:
            logger.warning(f"FAIL: {table}.{column} has {null_count} null values")
        else:
            logger.info(f"PASS: {table}.{column} not null check")

        return passed

    def check_unique(self, table: str, column: str) -> bool:
        """
        Check that a column has no duplicate values.

        Args:
            table: Table name.
            column: Column name.

        Returns:
            True if check passes (no duplicates found).
        """
        query = f"""
            SELECT COUNT(*) as dup_count
            FROM (
                SELECT {column}, COUNT(*) as cnt
                FROM public.{table}
                GROUP BY {column}
                HAVING COUNT(*) > 1
            ) x
        """
        result = run_query(query)
        dup_count = result[0]["dup_count"]
        passed = dup_count == 0

        self.results.append({
            "table": table,
            "check": f"unique_{column}",
            "passed": passed,
            "details": f"{dup_count} duplicate values found"
        })

        if not passed:
            logger.warning(f"FAIL: {table}.{column} has {dup_count} duplicates")
        else:
            logger.info(f"PASS: {table}.{column} unique check")

        return passed

    def check_attribution_sums_to_one(self) -> bool:
        """
        Validate that revenue attribution percentages sum to 1.0
        for each customer per month.

        Returns:
            True if all customer-months have attribution summing to 1.0.
        """
        query = """
            SELECT COUNT(*) as bad_count
            FROM (
                SELECT customer_key, revenue_month,
                       ROUND(SUM(attribution_percentage), 4) as pct_sum
                FROM public.fact_revenue_attribution
                GROUP BY 1, 2
                HAVING ABS(SUM(attribution_percentage) - 1.0) > 0.01
            ) x
        """
        result = run_query(query)
        bad_count = result[0]["bad_count"]
        passed = bad_count == 0

        self.results.append({
            "table": "fact_revenue_attribution",
            "check": "attribution_sums_to_one",
            "passed": passed,
            "details": f"{bad_count} customer-months with incorrect attribution sum"
        })

        if not passed:
            logger.warning(f"FAIL: {bad_count} customer-months have attribution != 1.0")
        else:
            logger.info("PASS: All attribution percentages sum to 1.0")

        return passed

    def check_revenue_ties_out(self) -> bool:
        """
        Validate that attributed revenue matches subscription monthly value
        for each customer per month.

        Returns:
            True if revenue ties out for all customer-months.
        """
        query = """
            SELECT COUNT(*) as bad_count
            FROM (
                SELECT customer_key, revenue_month,
                       ROUND(SUM(attributed_revenue), 2) as attributed_sum,
                       ROUND(MAX(subscription_monthly_value), 2) as monthly_value
                FROM public.fact_revenue_attribution
                GROUP BY 1, 2
                HAVING ABS(SUM(attributed_revenue) - MAX(subscription_monthly_value)) > 0.05
            ) x
        """
        result = run_query(query)
        bad_count = result[0]["bad_count"]
        passed = bad_count == 0

        self.results.append({
            "table": "fact_revenue_attribution",
            "check": "revenue_ties_out",
            "passed": passed,
            "details": f"{bad_count} customer-months with revenue mismatch"
        })

        if not passed:
            logger.warning(f"FAIL: {bad_count} customer-months have revenue mismatch")
        else:
            logger.info("PASS: All attributed revenue matches subscription value")

        return passed

    def get_summary(self) -> Dict:
        """
        Return a summary of all quality check results.

        Returns:
            Dictionary with total, passed, failed counts and details.
        """
        total = len(self.results)
        passed = sum(1 for r in self.results if r["passed"])

        return {
            "total_checks": total,
            "passed": passed,
            "failed": total - passed,
            "pass_rate": round(passed / total * 100, 1) if total > 0 else 0,
            "results": self.results
        }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    checker = DataQualityChecker()

    checker.check_not_null("fact_revenue_attribution", "attributed_revenue")
    checker.check_unique("fact_revenue_attribution", "revenue_key")
    checker.check_attribution_sums_to_one()
    checker.check_revenue_ties_out()

    summary = checker.get_summary()
    print(f"\nData Quality Summary: {summary['passed']}/{summary['total_checks']} passed")
