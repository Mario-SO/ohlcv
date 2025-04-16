#!/usr/bin/env python
"""
update_assets.py
----------------
Fetch OHLCV for several tickers from Yahoo Finance (via yfinance).

• If the asset’s CSV does *not* exist, pull the entire history ("max").
• Otherwise, pull just the last two days and append the new bar.
• Creates ./data if missing and keeps each asset in its own CSV.

Edit the TICKERS dict to add/remove symbols.
"""

import pathlib
import pandas as pd
import yfinance as yf

# ────────────────────────────────────────────────────────────────────────────────
# Config – add more assets here if you like
# ────────────────────────────────────────────────────────────────────────────────
TICKERS = {
    "btc":   "BTC-USD",   # Bitcoin
    "eth":   "ETH-USD",   # Ethereum
    "gold":  "GC=F",      # COMEX continuous gold future
    "sp500": "^GSPC",     # S&P 500 index
}

DATA_DIR = pathlib.Path("data")
DATA_DIR.mkdir(exist_ok=True)  # Ensure ./data exists

# ────────────────────────────────────────────────────────────────────────────────
# Main loop
# ────────────────────────────────────────────────────────────────────────────────
for name, yf_symbol in TICKERS.items():
    csv_path = DATA_DIR / f"{name}.csv"

    # Pull full history if first run, else just the last two days
    period = "max" if not csv_path.exists() else "2d"

    df_new = (
        yf.Ticker(yf_symbol)
        .history(period=period)
        [["Open", "High", "Low", "Close", "Volume"]]
    )

    # yfinance returns timezone‑aware index; drop TZ so it plays nicely with CSV
    df_new.index = df_new.index.tz_localize(None)
    df_new.index.name = "Date"

    if csv_path.exists():
        df_old = pd.read_csv(csv_path, parse_dates=["Date"], index_col="Date")
        # Keep only genuinely new rows (in case of reruns or weekends)
        df_new = df_new[~df_new.index.isin(df_old.index)]
        if df_new.empty:
            print(f"{name}: up‑to‑date")
            continue
        combined = pd.concat([df_old, df_new])
    else:
        combined = df_new

    combined.to_csv(csv_path, float_format="%.8f")
    print(f"{name}: wrote {len(df_new)} new rows (total {len(combined)})")
