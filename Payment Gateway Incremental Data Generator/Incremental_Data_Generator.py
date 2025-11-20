import pandas as pd
import random
import os
from datetime import datetime, timedelta
import numpy as np

# ==================== CONFIGURATION SECTION ====================
# Edit these variables to control data generation

# Row counts for each day
DAY1_ROWS = 15000
DAY2_ROWS = 15000
DAY3_ROWS = 15000

# Issue percentages (auto-scale with row counts)
LATE_ARRIVING_PCT = 0.01      # 1% of Day 2 rows
NULL_UPDATED_AT_PCT = 0.01    # 1% of Day 2 rows
MERCHANT_UPDATE_PCT = 0.02    # 2% of Day 3 rows
TIMEZONE_ISSUE_PCT = 0.0133   # 1.33% of Day 3 rows

# Master data counts
NUM_CUSTOMERS = 1000
NUM_MERCHANTS = 500

# Date configuration
DAY1_DATE = "2024-11-01"
DAY2_DATE = "2024-11-02"
DAY3_DATE = "2024-11-03"

# ==================== MASTER DATA LISTS ====================

# Product Categories
PRODUCT_CATEGORIES = ['Electronics', 'Fashion', 'Food', 'Groceries', 'Travel', 
                      'Entertainment', 'Health', 'Education', 'Bills', 'Others']

# Merchant Names (Mix of real Indian brands and generic)
MERCHANT_NAMES = [
    # E-commerce
    "Amazon India", "Flipkart", "Meesho", "Myntra", "Ajio", "Snapdeal",
    # Food Delivery
    "Swiggy", "Zomato", "Dunzo", "BigBasket", "Blinkit",
    # Travel
    "MakeMyTrip", "Goibibo", "Ola", "Uber India", "Redbus",
    # Entertainment
    "BookMyShow", "Netflix India", "Amazon Prime Video", "Hotstar",
    # Others
    "Paytm Mall", "PhonePe Store", "Reliance Digital", "Croma",
    # Generic merchants (will fill remaining slots)
    "ShopEasy India", "QuickMart", "TechWorld", "FashionHub", "FoodExpress",
    "GroceryKing", "TravelMate", "EntertainPlus", "HealthFirst", "EduPoint"
]

# Product Names by Category
PRODUCTS_BY_CATEGORY = {
    'Electronics': [
        "Samsung Galaxy S23", "iPhone 15", "OnePlus 11", "Realme Narzo",
        "MacBook Air M2", "Dell XPS 13", "HP Pavilion", "Lenovo ThinkPad",
        "Sony WH-1000XM5", "Boat Airdopes", "JBL Flip 6", "Amazon Echo Dot",
        "Samsung 55\" TV", "LG OLED TV", "Mi TV", "Canon EOS Camera"
    ],
    'Fashion': [
        "Nike Air Max", "Adidas Ultraboost", "Puma RS-X", "Reebok Classic",
        "Levi's Jeans", "H&M T-Shirt", "Zara Dress", "Van Heusen Shirt",
        "Allen Solly Trousers", "Peter England Suit", "Woodland Shoes",
        "Bata Sandals", "Fastrack Watch", "Titan Watch", "Ray-Ban Sunglasses"
    ],
    'Food': [
        "Biryani Meal", "Pizza Large", "Burger Combo", "Masala Dosa",
        "Chicken Tikka", "Paneer Butter Masala", "Veg Thali", "Noodles Bowl",
        "Sushi Platter", "Pasta Carbonara", "Ice Cream Tub", "Cake 1kg"
    ],
    'Groceries': [
        "Rice 25kg", "Wheat Flour 10kg", "Cooking Oil 5L", "Sugar 5kg",
        "Tea Powder 1kg", "Coffee Powder 500g", "Milk 2L", "Eggs Dozen",
        "Vegetables Basket", "Fruits Basket", "Chicken 1kg", "Fish 1kg"
    ],
    'Travel': [
        "Flight Delhi-Mumbai", "Train Ticket AC", "Bus Ticket Volvo",
        "Cab Ride 20km", "Hotel 1 Night", "Resort Package", "Tour Package",
        "Car Rental Daily", "Bike Rental", "Metro Card Recharge"
    ],
    'Entertainment': [
        "Movie Ticket 2", "Concert Pass", "IPL Match Ticket", "Game CD",
        "Spotify Premium", "YouTube Premium", "Gaming Console", "VR Headset",
        "Book Novel", "Magazine Subscription", "Streaming Bundle"
    ],
    'Health': [
        "Medicine Pack", "Vitamin Supplements", "Protein Powder 1kg",
        "Gym Membership", "Yoga Mat", "Fitness Band", "Blood Test Package",
        "Doctor Consultation", "Health Insurance Premium", "Medical Checkup"
    ],
    'Education': [
        "Online Course Fee", "Textbook Set", "Laptop for Study", "Notebook Pack",
        "School Fee Payment", "Tuition Fee", "Certification Exam", "Workshop Pass",
        "E-Learning Subscription", "Educational Software", "Study Lamp"
    ],
    'Bills': [
        "Electricity Bill", "Water Bill", "Gas Cylinder", "Mobile Recharge",
        "DTH Recharge", "Broadband Bill", "Credit Card Payment", "Loan EMI",
        "Insurance Premium", "Property Tax", "Maintenance Charges"
    ],
    'Others': [
        "Gift Card", "Donation", "Subscription Box", "Pet Food", "Plants",
        "Home Decor Item", "Kitchenware", "Tools Set", "Sports Equipment",
        "Stationery Set", "Toys Pack", "Baby Products", "Cosmetics"
    ]
}

# Payment Methods and their probabilities
PAYMENT_METHODS = {
    'UPI': 0.60,
    'Credit Card': 0.15,
    'Debit Card': 0.15,
    'Wallet Balance': 0.07,
    'Bank Transfer': 0.03
}

# Transaction Status and their probabilities
TRANSACTION_STATUSES = {
    'Successful': 0.95,
    'Failed': 0.04,
    'Pending': 0.01
}

# Device Types and their probabilities
DEVICE_TYPES = {
    'Android': 0.60,
    'iOS': 0.30,
    'Web': 0.10
}

# Location Types and their probabilities
LOCATION_TYPES = {
    'Urban': 0.70,
    'Suburban': 0.20,
    'Rural': 0.10
}

# ==================== HELPER FUNCTIONS ====================

def generate_transaction_id(date_str, sequence):
    """Generate unique transaction ID: TXN_20241101_000001"""
    clean_date = date_str.replace("-", "")
    return f"TXN_{clean_date}_{sequence:06d}"

def generate_customer_id(num):
    """Generate customer ID: USER_0001"""
    return f"USER_{num:04d}"

def generate_merchant_id(num):
    """Generate merchant ID: MERCH_0001"""
    return f"MERCH_{num:04d}"

def get_random_timestamp(date_str, start_hour=0, end_hour=23):
    """Generate random timestamp within a date range"""
    base_date = datetime.strptime(date_str, "%Y-%m-%d")
    random_hour = random.randint(start_hour, end_hour)
    random_minute = random.randint(0, 59)
    random_second = random.randint(0, 59)
    return base_date + timedelta(hours=random_hour, minutes=random_minute, seconds=random_second)

def get_merchant_name(merchant_id_num):
    """Get merchant name based on merchant ID"""
    if merchant_id_num < len(MERCHANT_NAMES):
        return MERCHANT_NAMES[merchant_id_num]
    else:
        return f"Merchant_{merchant_id_num:04d}"

def get_product_name(category):
    """Get random product name for a category"""
    return random.choice(PRODUCTS_BY_CATEGORY[category])

def calculate_fee(amount):
    """Calculate gateway fee (1.5% to 3% of amount)"""
    return round(amount * random.uniform(0.015, 0.03), 2)

def calculate_cashback(amount, status):
    """Calculate cashback (0-5% for successful transactions only)"""
    if status == 'Successful':
        return round(amount * random.uniform(0, 0.05), 2)
    return 0.0

def calculate_loyalty_points(amount, status):
    """Calculate loyalty points (0 to amount/10 for successful transactions)"""
    if status == 'Successful':
        return int(amount / random.uniform(10, 20))
    return 0

def weighted_random_choice(choices_dict):
    """Select random item based on probability weights"""
    items = list(choices_dict.keys())
    weights = list(choices_dict.values())
    return random.choices(items, weights=weights, k=1)[0]

def generate_amount():
    """Generate transaction amount using log-normal distribution (₹100 to ₹50,000)"""
    # Log-normal distribution centered around ₹2000-3000
    amount = np.random.lognormal(mean=7.5, sigma=1.0)
    amount = max(100, min(50000, amount))  # Clamp between 100 and 50000
    return round(amount, 2)

# ==================== DAY 1 DATA GENERATION ====================

def generate_day1_data():
    """Generate Day 1 clean baseline data"""
    print(f"\n🔄 Generating Day 1 data ({DAY1_ROWS:,} rows)...")
    
    data = []
    transaction_counter = 1
    
    for i in range(DAY1_ROWS):
        # Basic IDs
        transaction_id = generate_transaction_id(DAY1_DATE, transaction_counter)
        customer_id = generate_customer_id(random.randint(1, NUM_CUSTOMERS))
        merchant_id_num = random.randint(1, NUM_MERCHANTS)
        merchant_id = generate_merchant_id(merchant_id_num)
        
        # Transaction details
        transaction_timestamp = get_random_timestamp(DAY1_DATE)
        merchant_name = get_merchant_name(merchant_id_num - 1)
        product_category = random.choice(PRODUCT_CATEGORIES)
        product_name = get_product_name(product_category)
        
        # Financial details
        amount = generate_amount()
        fee_amount = calculate_fee(amount)
        transaction_status = weighted_random_choice(TRANSACTION_STATUSES)
        cashback_amount = calculate_cashback(amount, transaction_status)
        loyalty_points = calculate_loyalty_points(amount, transaction_status)
        
        # Other details
        payment_method = weighted_random_choice(PAYMENT_METHODS)
        device_type = weighted_random_choice(DEVICE_TYPES)
        location_type = weighted_random_choice(LOCATION_TYPES)
        currency = "INR"
        
        # For Day 1, updated_at = transaction_timestamp (no updates yet)
        updated_at = transaction_timestamp
        
        data.append({
            'transaction_id': transaction_id,
            'customer_id': customer_id,
            'transaction_timestamp': transaction_timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            'merchant_id': merchant_id,
            'merchant_name': merchant_name,
            'product_category': product_category,
            'product_name': product_name,
            'amount': amount,
            'fee_amount': fee_amount,
            'cashback_amount': cashback_amount,
            'loyalty_points': loyalty_points,
            'payment_method': payment_method,
            'transaction_status': transaction_status,
            'device_type': device_type,
            'location_type': location_type,
            'currency': currency,
            'updated_at': updated_at.strftime("%Y-%m-%d %H:%M:%S")
        })
        
        transaction_counter += 1
        
        # Progress indicator
        if (i + 1) % 5000 == 0:
            print(f"   Generated {i + 1:,} rows...")
    
    df = pd.DataFrame(data)
    print(f"✅ Day 1 complete: {len(df):,} rows")
    return df

# ==================== DAY 2 DATA GENERATION ====================

def generate_day2_data():
    """Generate Day 2 data with late-arriving and NULL issues"""
    print(f"\n🔄 Generating Day 2 data ({DAY2_ROWS:,} rows)...")
    
    # Calculate issue counts
    late_arriving_count = int(DAY2_ROWS * LATE_ARRIVING_PCT)
    null_updated_count = int(DAY2_ROWS * NULL_UPDATED_AT_PCT)
    clean_count = DAY2_ROWS - late_arriving_count - null_updated_count
    
    print(f"   📊 Clean rows: {clean_count:,}")
    print(f"   ⚠️  Late-arriving rows: {late_arriving_count:,}")
    print(f"   ⚠️  NULL updated_at rows: {null_updated_count:,}")
    
    data = []
    transaction_counter = 1
    
    # Generate clean rows
    for i in range(clean_count):
        transaction_id = generate_transaction_id(DAY2_DATE, transaction_counter)
        customer_id = generate_customer_id(random.randint(1, NUM_CUSTOMERS))
        merchant_id_num = random.randint(1, NUM_MERCHANTS)
        merchant_id = generate_merchant_id(merchant_id_num)
        
        transaction_timestamp = get_random_timestamp(DAY2_DATE)
        merchant_name = get_merchant_name(merchant_id_num - 1)
        product_category = random.choice(PRODUCT_CATEGORIES)
        product_name = get_product_name(product_category)
        
        amount = generate_amount()
        fee_amount = calculate_fee(amount)
        transaction_status = weighted_random_choice(TRANSACTION_STATUSES)
        cashback_amount = calculate_cashback(amount, transaction_status)
        loyalty_points = calculate_loyalty_points(amount, transaction_status)
        
        payment_method = weighted_random_choice(PAYMENT_METHODS)
        device_type = weighted_random_choice(DEVICE_TYPES)
        location_type = weighted_random_choice(LOCATION_TYPES)
        currency = "INR"
        
        updated_at = transaction_timestamp
        
        data.append({
            'transaction_id': transaction_id,
            'customer_id': customer_id,
            'transaction_timestamp': transaction_timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            'merchant_id': merchant_id,
            'merchant_name': merchant_name,
            'product_category': product_category,
            'product_name': product_name,
            'amount': amount,
            'fee_amount': fee_amount,
            'cashback_amount': cashback_amount,
            'loyalty_points': loyalty_points,
            'payment_method': payment_method,
            'transaction_status': transaction_status,
            'device_type': device_type,
            'location_type': location_type,
            'currency': currency,
            'updated_at': updated_at.strftime("%Y-%m-%d %H:%M:%S")
        })
        
        transaction_counter += 1
    
    # Generate late-arriving rows (transaction_timestamp = Day 1, updated_at = Day 2)
    print(f"   🔄 Adding late-arriving rows...")
    for i in range(late_arriving_count):
        transaction_id = generate_transaction_id(DAY2_DATE, transaction_counter)
        customer_id = generate_customer_id(random.randint(1, NUM_CUSTOMERS))
        merchant_id_num = random.randint(1, NUM_MERCHANTS)
        merchant_id = generate_merchant_id(merchant_id_num)
        
        # Transaction happened on Day 1, but recorded on Day 2
        transaction_timestamp = get_random_timestamp(DAY1_DATE)
        updated_at = get_random_timestamp(DAY2_DATE)
        
        merchant_name = get_merchant_name(merchant_id_num - 1)
        product_category = random.choice(PRODUCT_CATEGORIES)
        product_name = get_product_name(product_category)
        
        amount = generate_amount()
        fee_amount = calculate_fee(amount)
        transaction_status = weighted_random_choice(TRANSACTION_STATUSES)
        cashback_amount = calculate_cashback(amount, transaction_status)
        loyalty_points = calculate_loyalty_points(amount, transaction_status)
        
        payment_method = weighted_random_choice(PAYMENT_METHODS)
        device_type = weighted_random_choice(DEVICE_TYPES)
        location_type = weighted_random_choice(LOCATION_TYPES)
        currency = "INR"
        
        data.append({
            'transaction_id': transaction_id,
            'customer_id': customer_id,
            'transaction_timestamp': transaction_timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            'merchant_id': merchant_id,
            'merchant_name': merchant_name,
            'product_category': product_category,
            'product_name': product_name,
            'amount': amount,
            'fee_amount': fee_amount,
            'cashback_amount': cashback_amount,
            'loyalty_points': loyalty_points,
            'payment_method': payment_method,
            'transaction_status': transaction_status,
            'device_type': device_type,
            'location_type': location_type,
            'currency': currency,
            'updated_at': updated_at.strftime("%Y-%m-%d %H:%M:%S")
        })
        
        transaction_counter += 1
    
    # Generate NULL updated_at rows
    print(f"   🔄 Adding NULL updated_at rows...")
    for i in range(null_updated_count):
        transaction_id = generate_transaction_id(DAY2_DATE, transaction_counter)
        customer_id = generate_customer_id(random.randint(1, NUM_CUSTOMERS))
        merchant_id_num = random.randint(1, NUM_MERCHANTS)
        merchant_id = generate_merchant_id(merchant_id_num)
        
        transaction_timestamp = get_random_timestamp(DAY2_DATE)
        merchant_name = get_merchant_name(merchant_id_num - 1)
        product_category = random.choice(PRODUCT_CATEGORIES)
        product_name = get_product_name(product_category)
        
        amount = generate_amount()
        fee_amount = calculate_fee(amount)
        transaction_status = weighted_random_choice(TRANSACTION_STATUSES)
        cashback_amount = calculate_cashback(amount, transaction_status)
        loyalty_points = calculate_loyalty_points(amount, transaction_status)
        
        payment_method = weighted_random_choice(PAYMENT_METHODS)
        device_type = weighted_random_choice(DEVICE_TYPES)
        location_type = weighted_random_choice(LOCATION_TYPES)
        currency = "INR"
        
        data.append({
            'transaction_id': transaction_id,
            'customer_id': customer_id,
            'transaction_timestamp': transaction_timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            'merchant_id': merchant_id,
            'merchant_name': merchant_name,
            'product_category': product_category,
            'product_name': product_name,
            'amount': amount,
            'fee_amount': fee_amount,
            'cashback_amount': cashback_amount,
            'loyalty_points': loyalty_points,
            'payment_method': payment_method,
            'transaction_status': transaction_status,
            'device_type': device_type,
            'location_type': location_type,
            'currency': currency,
            'updated_at': None  # NULL value
        })
        
        transaction_counter += 1
    
    df = pd.DataFrame(data)
    print(f"✅ Day 2 complete: {len(df):,} rows")
    return df

# ==================== DAY 3 DATA GENERATION ====================

def generate_day3_data():
    """Generate Day 3 data with merchant updates and timezone issues"""
    print(f"\n🔄 Generating Day 3 data ({DAY3_ROWS:,} rows)...")
    
    # Calculate issue counts
    merchant_update_count = int(DAY3_ROWS * MERCHANT_UPDATE_PCT)
    timezone_issue_count = int(DAY3_ROWS * TIMEZONE_ISSUE_PCT)
    clean_count = DAY3_ROWS - merchant_update_count - timezone_issue_count
    
    print(f"   📊 Clean rows: {clean_count:,}")
    print(f"   ⚠️  Merchant update rows: {merchant_update_count:,}")
    print(f"   ⚠️  Timezone issue rows: {timezone_issue_count:,}")
    
    data = []
    transaction_counter = 1
    
    # Generate clean rows
    for i in range(clean_count):
        transaction_id = generate_transaction_id(DAY3_DATE, transaction_counter)
        customer_id = generate_customer_id(random.randint(1, NUM_CUSTOMERS))
        merchant_id_num = random.randint(1, NUM_MERCHANTS)
        merchant_id = generate_merchant_id(merchant_id_num)
        
        transaction_timestamp = get_random_timestamp(DAY3_DATE)
        merchant_name = get_merchant_name(merchant_id_num - 1)
        product_category = random.choice(PRODUCT_CATEGORIES)
        product_name = get_product_name(product_category)
        
        amount = generate_amount()
        fee_amount = calculate_fee(amount)
        transaction_status = weighted_random_choice(TRANSACTION_STATUSES)
        cashback_amount = calculate_cashback(amount, transaction_status)
        loyalty_points = calculate_loyalty_points(amount, transaction_status)
        
        payment_method = weighted_random_choice(PAYMENT_METHODS)
        device_type = weighted_random_choice(DEVICE_TYPES)
        location_type = weighted_random_choice(LOCATION_TYPES)
        currency = "INR"
        
        updated_at = transaction_timestamp
        
        data.append({
            'transaction_id': transaction_id,
            'customer_id': customer_id,
            'transaction_timestamp': transaction_timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            'merchant_id': merchant_id,
            'merchant_name': merchant_name,
            'product_category': product_category,
            'product_name': product_name,
            'amount': amount,
            'fee_amount': fee_amount,
            'cashback_amount': cashback_amount,
            'loyalty_points': loyalty_points,
            'payment_method': payment_method,
            'transaction_status': transaction_status,
            'device_type': device_type,
            'location_type': location_type,
            'currency': currency,
            'updated_at': updated_at.strftime("%Y-%m-%d %H:%M:%S")
        })
        
        transaction_counter += 1
    
    # Generate merchant update rows (same merchant_id, updated merchant_name)
    print(f"   🔄 Adding merchant update rows...")
    merchant_name_updates = {
        "Amazon India": "Amazon India Pvt Ltd",
        "Flipkart": "Flipkart Internet Pvt Ltd",
        "Swiggy": "Swiggy Ltd",
        "Zomato": "Zomato Media Pvt Ltd",
        "MakeMyTrip": "MakeMyTrip India Pvt Ltd",
        "Paytm Mall": "Paytm E-Commerce Pvt Ltd",
        "BookMyShow": "BookMyShow Entertainment Pvt Ltd",
        "Reliance Digital": "Reliance Retail Digital",
        "Ola": "Ola Fleet Technologies",
        "PhonePe Store": "PhonePe Internet Pvt Ltd"
    }
    
    for i in range(merchant_update_count):
        transaction_id = generate_transaction_id(DAY3_DATE, transaction_counter)
        customer_id = generate_customer_id(random.randint(1, NUM_CUSTOMERS))
        merchant_id_num = random.randint(1, min(NUM_MERCHANTS, len(MERCHANT_NAMES)))
        merchant_id = generate_merchant_id(merchant_id_num)
        
        transaction_timestamp = get_random_timestamp(DAY3_DATE)
        
        # Get original merchant name and update it
        original_name = get_merchant_name(merchant_id_num - 1)
        merchant_name = merchant_name_updates.get(original_name, f"{original_name} Ltd")
        
        product_category = random.choice(PRODUCT_CATEGORIES)
        product_name = get_product_name(product_category)
        
        amount = generate_amount()
        fee_amount = calculate_fee(amount)
        transaction_status = weighted_random_choice(TRANSACTION_STATUSES)
        cashback_amount = calculate_cashback(amount, transaction_status)
        loyalty_points = calculate_loyalty_points(amount, transaction_status)
        
        payment_method = weighted_random_choice(PAYMENT_METHODS)
        device_type = weighted_random_choice(DEVICE_TYPES)
        location_type = weighted_random_choice(LOCATION_TYPES)
        currency = "INR"
        
        updated_at = transaction_timestamp
        
        data.append({
            'transaction_id': transaction_id,
            'customer_id': customer_id,
            'transaction_timestamp': transaction_timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            'merchant_id': merchant_id,
            'merchant_name': merchant_name,
            'product_category': product_category,
            'product_name': product_name,
            'amount': amount,
            'fee_amount': fee_amount,
            'cashback_amount': cashback_amount,
            'loyalty_points': loyalty_points,
            'payment_method': payment_method,
            'transaction_status': transaction_status,
            'device_type': device_type,
            'location_type': location_type,
            'currency': currency,
            'updated_at': updated_at.strftime("%Y-%m-%d %H:%M:%S")
        })
        
        transaction_counter += 1
    
    # Generate timezone issue rows (transaction_timestamp in EST, updated_at in IST)
    print(f"   🔄 Adding timezone issue rows...")
    for i in range(timezone_issue_count):
        transaction_id = generate_transaction_id(DAY3_DATE, transaction_counter)
        customer_id = generate_customer_id(random.randint(1, NUM_CUSTOMERS))
        merchant_id_num = random.randint(1, NUM_MERCHANTS)
        merchant_id = generate_merchant_id(merchant_id_num)
        
        # Transaction timestamp in EST (subtract 10.5 hours from IST to get EST equivalent)
        transaction_timestamp_ist = get_random_timestamp(DAY3_DATE)
        transaction_timestamp_est = transaction_timestamp_ist - timedelta(hours=10, minutes=30)
        
        # updated_at in IST
        updated_at = get_random_timestamp(DAY3_DATE)
        
        merchant_name = get_merchant_name(merchant_id_num - 1)
        product_category = random.choice(PRODUCT_CATEGORIES)
        product_name = get_product_name(product_category)
        
        amount = generate_amount()
        fee_amount = calculate_fee(amount)
        transaction_status = weighted_random_choice(TRANSACTION_STATUSES)
        cashback_amount = calculate_cashback(amount, transaction_status)
        loyalty_points = calculate_loyalty_points(amount, transaction_status)
        
        payment_method = weighted_random_choice(PAYMENT_METHODS)
        device_type = weighted_random_choice(DEVICE_TYPES)
        location_type = weighted_random_choice(LOCATION_TYPES)
        currency = "INR"
        
        data.append({
            'transaction_id': transaction_id,
            'customer_id': customer_id,
            'transaction_timestamp': transaction_timestamp_est.strftime("%Y-%m-%d %H:%M:%S"),
            'merchant_id': merchant_id,
            'merchant_name': merchant_name,
            'product_category': product_category,
            'product_name': product_name,
            'amount': amount,
            'fee_amount': fee_amount,
            'cashback_amount': cashback_amount,
            'loyalty_points': loyalty_points,
            'payment_method': payment_method,
            'transaction_status': transaction_status,
            'device_type': device_type,
            'location_type': location_type,
            'currency': currency,
            'updated_at': updated_at.strftime("%Y-%m-%d %H:%M:%S")
        })
        
        transaction_counter += 1
    
    df = pd.DataFrame(data)
    print(f"✅ Day 3 complete: {len(df):,} rows")
    return df

# ==================== VALIDATION & FILE SAVING ====================

def format_file_size(size_bytes):
    """Convert bytes to human-readable format"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f}{unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f}TB"

def validate_and_save_data(df_day1, df_day2, df_day3):
    """Validate data quality and save to CSV files in timestamped folder"""
    print("\n" + "="*70)
    print("📊 DATA VALIDATION & SAVING")
    print("="*70)
    
    # Create output folder with timestamp and size info
    now = datetime.now()
    folder_date = now.strftime("%b%d_%Y")
    folder_time = now.strftime("%Hh%Mm")
    
    total_rows = len(df_day1) + len(df_day2) + len(df_day3)
    row_summary = f"{len(df_day1)//1000}K+{len(df_day2)//1000}K+{len(df_day3)//1000}K"
    
    # Create folder (will calculate size after saving files)
    folder_name = f"incremental_data_{folder_date}_{folder_time}_{row_summary}"
    
    # Use current directory for Windows compatibility
    current_dir = os.getcwd()
    output_dir = os.path.join(current_dir, folder_name)
    
    os.makedirs(output_dir, exist_ok=True)
    print(f"\n📁 Output folder: {output_dir}")
    
    # Save Day 1
    print(f"\n💾 Saving Day 1 data...")
    day1_path = os.path.join(output_dir, "day1_transactions.csv")
    df_day1.to_csv(day1_path, index=False, encoding='utf-8')
    day1_size = os.path.getsize(day1_path)
    print(f"   ✅ day1_transactions.csv saved ({format_file_size(day1_size)})")
    
    # Save Day 2
    print(f"\n💾 Saving Day 2 data...")
    day2_path = os.path.join(output_dir, "day2_transactions.csv")
    df_day2.to_csv(day2_path, index=False, encoding='utf-8')
    day2_size = os.path.getsize(day2_path)
    print(f"   ✅ day2_transactions.csv saved ({format_file_size(day2_size)})")
    
    # Save Day 3
    print(f"\n💾 Saving Day 3 data...")
    day3_path = os.path.join(output_dir, "day3_transactions.csv")
    df_day3.to_csv(day3_path, index=False, encoding='utf-8')
    day3_size = os.path.getsize(day3_path)
    print(f"   ✅ day3_transactions.csv saved ({format_file_size(day3_size)})")
    
    # Calculate total size and rename folder
    total_size = day1_size + day2_size + day3_size
    total_size_str = format_file_size(total_size)
    
    # Rename folder with size info
    new_folder_name = f"incremental_data_{folder_date}_{folder_time}_{row_summary}_{total_size_str.replace('.', '_')}"
    new_output_dir = os.path.join(current_dir, new_folder_name)
    
    os.rename(output_dir, new_output_dir)
    print(f"\n📦 Final folder: {new_folder_name}")
    
    # Validation statistics
    print("\n" + "="*70)
    print("🔍 VALIDATION STATISTICS")
    print("="*70)
    
    # Day 1 Validation
    print("\n=== DAY 1 VALIDATION ===")
    print(f"Total Rows: {len(df_day1):,}")
    print(f"Unique transaction_id: {df_day1['transaction_id'].nunique():,}")
    print(f"Unique customer_id: {df_day1['customer_id'].nunique():,}")
    print(f"Unique merchant_id: {df_day1['merchant_id'].nunique():,}")
    print(f"Date Range: {df_day1['transaction_timestamp'].min()} to {df_day1['transaction_timestamp'].max()}")
    print(f"NULL updated_at: {df_day1['updated_at'].isna().sum():,}")
    print(f"Transaction Status Distribution:")
    print(f"  - Successful: {(df_day1['transaction_status'] == 'Successful').sum():,} ({(df_day1['transaction_status'] == 'Successful').sum()/len(df_day1)*100:.1f}%)")
    print(f"  - Failed: {(df_day1['transaction_status'] == 'Failed').sum():,} ({(df_day1['transaction_status'] == 'Failed').sum()/len(df_day1)*100:.1f}%)")
    print(f"  - Pending: {(df_day1['transaction_status'] == 'Pending').sum():,} ({(df_day1['transaction_status'] == 'Pending').sum()/len(df_day1)*100:.1f}%)")
    
    # Day 2 Validation
    print("\n=== DAY 2 VALIDATION ===")
    print(f"Total Rows: {len(df_day2):,}")
    print(f"Unique transaction_id: {df_day2['transaction_id'].nunique():,}")
    
    # Convert to datetime for comparison
    df_day2_temp = df_day2.copy()
    df_day2_temp['transaction_timestamp'] = pd.to_datetime(df_day2_temp['transaction_timestamp'])
    late_arriving = len(df_day2_temp[df_day2_temp['transaction_timestamp'] < DAY2_DATE])
    
    print(f"⚠️  Late-arriving rows (date < {DAY2_DATE}): {late_arriving:,}")
    print(f"⚠️  NULL updated_at: {df_day2['updated_at'].isna().sum():,}")
    print(f"Clean rows: {len(df_day2) - late_arriving - df_day2['updated_at'].isna().sum():,}")
    
    # Day 3 Validation
    print("\n=== DAY 3 VALIDATION ===")
    print(f"Total Rows: {len(df_day3):,}")
    print(f"Unique transaction_id: {df_day3['transaction_id'].nunique():,}")
    
    # Merchant updates detection
    merchant_update_keywords = ['Pvt Ltd', 'Ltd', 'Internet', 'Media', 'Technologies', 'Entertainment', 'Retail', 'E-Commerce', 'Fleet']
    merchant_updates = df_day3[df_day3['merchant_name'].str.contains('|'.join(merchant_update_keywords), na=False)]
    print(f"⚠️  Merchant update rows (name contains 'Pvt Ltd', 'Ltd', etc.): {len(merchant_updates):,}")
    
    # Timezone issues detection
    df_day3_temp = df_day3.copy()
    df_day3_temp['transaction_timestamp'] = pd.to_datetime(df_day3_temp['transaction_timestamp'])
    timezone_issues = len(df_day3_temp[df_day3_temp['transaction_timestamp'] < DAY3_DATE])
    print(f"⚠️  Timezone issue rows (date < {DAY3_DATE}): {timezone_issues:,}")
    
    print(f"Clean rows: {len(df_day3) - len(merchant_updates) - timezone_issues:,}")
    
    # Overall Summary
    print("\n" + "="*70)
    print("📈 OVERALL SUMMARY")
    print("="*70)
    print(f"Total Rows Generated: {total_rows:,}")
    print(f"Total CSV Files: 3")
    print(f"Total Size: {total_size_str}")
    print(f"Output Location: {new_output_dir}")
    print(f"\nAll transaction_ids unique: {df_day1['transaction_id'].nunique() + df_day2['transaction_id'].nunique() + df_day3['transaction_id'].nunique() == total_rows}")
    
    # Check for duplicate transaction_ids across days
    all_txn_ids = pd.concat([df_day1['transaction_id'], df_day2['transaction_id'], df_day3['transaction_id']])
    duplicates = all_txn_ids[all_txn_ids.duplicated()]
    if len(duplicates) > 0:
        print(f"⚠️  WARNING: Found {len(duplicates)} duplicate transaction_ids across days!")
    else:
        print(f"✅ No duplicate transaction_ids across all days")
    
    # Data Quality Issues Summary
    print("\n" + "="*70)
    print("🐛 DATA QUALITY ISSUES INJECTED (For Blog 2)")
    print("="*70)
    print(f"1. Late-Arriving Data (Day 2): {late_arriving:,} rows")
    print(f"2. NULL updated_at (Day 2): {df_day2['updated_at'].isna().sum():,} rows")
    print(f"3. Merchant Updates (Day 3): {len(merchant_updates):,} rows")
    print(f"4. Timezone Issues (Day 3): {timezone_issues:,} rows")
    print(f"\nTotal Issue Rows: {late_arriving + df_day2['updated_at'].isna().sum() + len(merchant_updates) + timezone_issues:,}")
    
    # Save validation report
    print("\n💾 Saving validation report...")
    report_path = os.path.join(new_output_dir, "validation_report.txt")
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("="*70 + "\n")
        f.write("PAYMENT GATEWAY INCREMENTAL DATA - VALIDATION REPORT\n")
        f.write("="*70 + "\n\n")
        f.write(f"Generation Time: {now.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total Rows: {total_rows:,}\n")
        f.write(f"Total Size: {total_size_str}\n\n")
        
        f.write("=== CONFIGURATION ===\n")
        f.write(f"DAY1_ROWS: {DAY1_ROWS:,}\n")
        f.write(f"DAY2_ROWS: {DAY2_ROWS:,}\n")
        f.write(f"DAY3_ROWS: {DAY3_ROWS:,}\n")
        f.write(f"NUM_CUSTOMERS: {NUM_CUSTOMERS}\n")
        f.write(f"NUM_MERCHANTS: {NUM_MERCHANTS}\n\n")
        
        f.write("=== DAY 1 ===\n")
        f.write(f"Total Rows: {len(df_day1):,}\n")
        f.write(f"File Size: {format_file_size(day1_size)}\n")
        f.write(f"Unique transaction_id: {df_day1['transaction_id'].nunique():,}\n")
        f.write(f"Unique customer_id: {df_day1['customer_id'].nunique():,}\n")
        f.write(f"Unique merchant_id: {df_day1['merchant_id'].nunique():,}\n\n")
        
        f.write("=== DAY 2 ===\n")
        f.write(f"Total Rows: {len(df_day2):,}\n")
        f.write(f"File Size: {format_file_size(day2_size)}\n")
        f.write(f"Late-Arriving Rows: {late_arriving:,}\n")
        f.write(f"NULL updated_at Rows: {df_day2['updated_at'].isna().sum():,}\n\n")
        
        f.write("=== DAY 3 ===\n")
        f.write(f"Total Rows: {len(df_day3):,}\n")
        f.write(f"File Size: {format_file_size(day3_size)}\n")
        f.write(f"Merchant Update Rows: {len(merchant_updates):,}\n")
        f.write(f"Timezone Issue Rows: {timezone_issues:,}\n\n")
        
        f.write("=== DATA QUALITY ISSUES ===\n")
        f.write(f"1. Late-Arriving Data: {late_arriving:,} rows\n")
        f.write(f"2. NULL updated_at: {df_day2['updated_at'].isna().sum():,} rows\n")
        f.write(f"3. Merchant Updates: {len(merchant_updates):,} rows\n")
        f.write(f"4. Timezone Issues: {timezone_issues:,} rows\n")
    
    print(f"   ✅ validation_report.txt saved")
    
    print("\n" + "="*70)
    print("🎉 DATA GENERATION COMPLETE!")
    print("="*70)
    print(f"\n📂 All files saved in: {new_output_dir}")
    print(f"\n✅ Ready for BigQuery upload!")
    print(f"✅ Ready for Blog 2: Incremental Load Patterns & Mistakes!")
    
    return new_output_dir

# ==================== MAIN EXECUTION ====================

def main():
    """Main execution function"""
    print("="*70)
    print("🚀 PAYMENT GATEWAY INCREMENTAL DATA GENERATOR")
    print("="*70)
    print(f"\nConfiguration:")
    print(f"  - Day 1 Rows: {DAY1_ROWS:,}")
    print(f"  - Day 2 Rows: {DAY2_ROWS:,}")
    print(f"  - Day 3 Rows: {DAY3_ROWS:,}")
    print(f"  - Total Rows: {DAY1_ROWS + DAY2_ROWS + DAY3_ROWS:,}")
    print(f"  - Customers: {NUM_CUSTOMERS}")
    print(f"  - Merchants: {NUM_MERCHANTS}")
    print(f"\nData Quality Issues:")
    print(f"  - Late-Arriving (Day 2): {LATE_ARRIVING_PCT*100:.1f}% = ~{int(DAY2_ROWS * LATE_ARRIVING_PCT):,} rows")
    print(f"  - NULL updated_at (Day 2): {NULL_UPDATED_AT_PCT*100:.1f}% = ~{int(DAY2_ROWS * NULL_UPDATED_AT_PCT):,} rows")
    print(f"  - Merchant Updates (Day 3): {MERCHANT_UPDATE_PCT*100:.1f}% = ~{int(DAY3_ROWS * MERCHANT_UPDATE_PCT):,} rows")
    print(f"  - Timezone Issues (Day 3): {TIMEZONE_ISSUE_PCT*100:.2f}% = ~{int(DAY3_ROWS * TIMEZONE_ISSUE_PCT):,} rows")
    
    # Set random seed for reproducibility
    random.seed(42)
    np.random.seed(42)
    
    start_time = datetime.now()
    
    # Generate data
    df_day1 = generate_day1_data()
    df_day2 = generate_day2_data()
    df_day3 = generate_day3_data()
    
    # Validate and save
    output_dir = validate_and_save_data(df_day1, df_day2, df_day3)
    
    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()
    
    print(f"\n⏱️  Total execution time: {duration:.2f} seconds")
    print(f"\n🎯 Next Steps:")
    print(f"   1. Navigate to: {output_dir}")
    print(f"   2. Upload CSV files to BigQuery Bronze layer")
    print(f"   3. Create tables: raw_transactions_day1, raw_transactions_day2, raw_transactions_day3")
    print(f"   4. Start building incremental load SQL for Blog 2!")
    
    print("\n" + "="*70)
    

if __name__ == "__main__":
    main()