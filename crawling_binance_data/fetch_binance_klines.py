import pandas as pd
import requests
import time
import os
from datetime import datetime
import argparse
from pandas_gbq import to_gbq
from google.oauth2 import service_account

# ---------------------------
# Configuration
# ---------------------------
OUTPUT_DIR = "output/raw_rates/"
os.makedirs(OUTPUT_DIR, exist_ok=True)
TRANSACTIONS_FILE = "../data/transactions.csv"
USERS_FILE = "../data/users.csv"
INTERVAL = "1h"  # Kline interval
SLEEP_BETWEEN_REQUESTS = 0.1  # seconds


# ---------------------------
# Functions
# ---------------------------
def load_transactions(file_path):
    df = pd.read_csv(file_path)
    df["created_at"] = pd.to_datetime(df["created_at"])
    start_date = df["created_at"].min()
    end_date = df["created_at"].max()
    currencies = df["destination_currency"].dropna().unique().tolist()
    return df, start_date, end_date, currencies


def load_users(file_path):
    df = pd.read_csv(file_path)
    return df


def build_tradable_symbols(currencies):
    return [f"{cur}USDT" for cur in currencies if cur != "USDT"]


def check_binance_symbols(tradable_symbols):
    info = requests.get("https://api.binance.com/api/v3/exchangeInfo").json()
    binance_symbols = {s["symbol"] for s in info["symbols"]}
    available = [s for s in tradable_symbols if s in binance_symbols]
    missing = [s for s in tradable_symbols if s not in binance_symbols]
    return available, missing


def transform_klines_vectorized(raw_klines, symbol):
    columns = [
        "open_time", "open", "high", "low", "close", "volume",
        "close_time", "quote_volume", "trades",
        "taker_buy_volume", "taker_buy_quote_volume", "ignore"
    ]
    df = pd.DataFrame(raw_klines, columns=columns)
    float_cols = ["open", "high", "low", "close", "volume",
                  "quote_volume", "taker_buy_volume", "taker_buy_quote_volume"]
    df[float_cols] = df[float_cols].astype(float)
    df["trades"] = df["trades"].astype(int)
    df["symbol"] = symbol
    return df


def fetch_all_klines(symbol, start_time, end_time):
    url = "https://api.binance.com/api/v3/klines"
    all_data = []
    current = start_time

    while True:
        params = {
            "symbol": symbol,
            "interval": INTERVAL,
            "startTime": current,
            "endTime": end_time,
            "limit": 1000
        }
        response = requests.get(url, params=params)
        data = response.json()

        if not data:
            break

        all_data.extend(data)
        last_open_time = data[-1][0]

        if last_open_time <= current:
            break

        current = last_open_time + 1
        if current > end_time:
            break

        time.sleep(SLEEP_BETWEEN_REQUESTS)

    return transform_klines_vectorized(all_data, symbol)


def load_to_bigquery(df, table_name, project_id, dataset, credentials):
    to_gbq(
        df,
        destination_table=f"{dataset}.{table_name}",
        project_id=project_id,
        if_exists="replace",
        credentials=credentials
    )
    print(f"Loaded {df.shape[0]} rows into {dataset}.{table_name} in BigQuery.")


# ---------------------------
# Main
# ---------------------------
if __name__ == "__main__":
    # Parse arguments
    parser = argparse.ArgumentParser(description="Fetch Binance klines and load transactions/users to BigQuery.")
    parser.add_argument("--project_id", required=True, help="GCP Project ID")
    parser.add_argument("--dataset", required=True, help="BigQuery dataset name (e.g., raw)")
    parser.add_argument("--credentials", required=True, help="Path to service account JSON file")
    args = parser.parse_args()

    # Load credentials
    credentials = service_account.Credentials.from_service_account_file(args.credentials)

    # Load transactions
    transactions_df, start_date, end_date, currencies = load_transactions(TRANSACTIONS_FILE)
    print("Transaction date range:", start_date, "to", end_date)
    print("Currencies in transactions:", currencies)

    # Load users
    users_df = load_users(USERS_FILE)
    print("Users DataFrame shape:", users_df.shape)

    # Convert to milliseconds for Binance API
    start_ms = int(start_date.timestamp() * 1000)
    end_ms = int(end_date.timestamp() * 1000)

    # Build tradable symbols
    tradable_symbols = build_tradable_symbols(currencies)
    print("Tradable symbols:", tradable_symbols)

    # Check Binance availability
    available_symbols, missing_symbols = check_binance_symbols(tradable_symbols)
    print("Available on Binance:", available_symbols)
    print("Not available:", missing_symbols)

    # Fetch Binance data
    all_symbols_df = []
    for symbol in available_symbols:
        print(f"Fetching {symbol} data...")
        df_symbol = fetch_all_klines(symbol, start_ms, end_ms)
        all_symbols_df.append(df_symbol)

    if all_symbols_df:
        binance_df = pd.concat(all_symbols_df, ignore_index=True)
        print("Combined Binance DataFrame shape:", binance_df.shape)
        binance_df.to_csv(os.path.join(OUTPUT_DIR, "all_binance_klines.csv"), index=False)
        print(f"Binance data saved to {OUTPUT_DIR}/all_binance_klines.csv")
    else:
        binance_df = pd.DataFrame()
        print("No Binance data fetched.")

    # Load to BigQuery
    load_to_bigquery(transactions_df, "transactions", args.project_id, args.dataset, credentials)
    load_to_bigquery(users_df, "users", args.project_id, args.dataset, credentials)
    if not binance_df.empty:
        load_to_bigquery(binance_df, "binance_klines", args.project_id, args.dataset, credentials)
