# Test fixtures

All CSV files here are **synthetic** and exist only for unit tests. They are not market history,
not tick data and must not be used to evaluate strategy performance.

- `synthetic_eurusd_m5.csv` — six valid M5 bars on 2024-01-01, EURUSD, UTC, for loader/validation
  happy-path tests. Tests pass `data_kind="synthetic"` so validation reports are labeled accordingly.

Malformed cases (empty file, missing columns, duplicates, out-of-order rows, bad OHLC, NaN/Inf) are
constructed in temporary directories by the tests instead of being committed.
