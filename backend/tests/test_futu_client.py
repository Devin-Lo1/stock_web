import pytest

from app.services.futu_client import (
    FutuOpenDError,
    _currency_from_code,
    _market_from_code,
)


@pytest.mark.parametrize(
    ("code", "market", "currency"),
    [
        ("HK.00700", "HK", "HKD"),
        ("US.AAPL", "US", "USD"),
        ("SH.510300", "SH", "CNY"),
        ("SZ.159919", "SZ", "CNY"),
    ],
)
def test_futu_market_and_currency_mapping(
    code: str,
    market: str,
    currency: str,
) -> None:
    assert _market_from_code(code) == market
    assert _currency_from_code(code) == currency


def test_futu_market_mapping_rejects_unknown_prefix() -> None:
    with pytest.raises(FutuOpenDError):
        _market_from_code("OF.000001")
