#!/usr/bin/env python
"""
Fetch yesterday's daily OHLCV for several tickers and append
to per‑asset CSVs in ./data. First run creates full history.
"""
import pathlib, pandas as pd, yfinance as yf

TICKERS = {
    "btc":   "BTC-USD",
    "eth":   "ETH-USD",
    "gold":  "GC=F",
    "sp500": "^GSPC",
}

DATA_DIR = pathlib.Path("data")
DATA_DIR.mkdir(exist_ok=True)

for name, yf_symbol in TICKERS.items():
    fn = DATA_DIR / f"{name}.csv"
    df_new = (
        yf.Ticker(yf_symbol)
        .history(period="2d")            # yesterday+today to be safe
        [["Open","High","Low","Close","Volume"]]
    )
    df_new.index = df_new.index.tz_localize(None)  # drop TZ
    df_new.index.name = "Date"

    if fn.exists():
        df_old = pd.read_csv(fn, parse_dates=["Date"], index_col="Date")
        df_new = df_new[~df_new.index.isin(df_old.index)]
        if df_new.empty:
            continue
        out = pd.concat([df_old, df_new])
    else:
        out = df_new

    out.to_csv(fn, float_format="%.8f")
    print(f"{name}: wrote {len(df_new)} new rows")

