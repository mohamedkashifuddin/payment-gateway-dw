import pandas as pd

# 🔹 Update this path if your folder name changes
base_path = r"E:\Pictures\payment-gateway-dw.git\payment-gateway-dw\incremental_data_Nov10_2025_13h07m_15K+15K+15K_7_60MB"

print("📂 Checking transaction files inside:")
print(base_path)

for day in [1, 2, 3]:
    file_path = f"{base_path}/day{day}_transactions.csv"
    df = pd.read_csv(file_path, parse_dates=['transaction_timestamp'])
    print(f"\n=== DAY {day} ===")
    print(f"File: day{day}_transactions.csv")
    print(f"Rows: {len(df):,}")
    print(f"Min transaction_timestamp: {df['transaction_timestamp'].min()}")
    print(f"Max transaction_timestamp: {df['transaction_timestamp'].max()}")
    print(f"NULL updated_at: {df['updated_at'].isna().sum():,}")
