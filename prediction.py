import pandas as pd
import numpy as np
import joblib
import mysql.connector
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report
from imblearn.over_sampling import SMOTE

# Database config
DB_CONFIG = {
    'host': 'localhost',
    'user': 'fraud_account',
    'password': 'secure_password125',
    'database': 'BankFraudDetection'
}

# Step 1: Connect to DB and fetch data
conn = mysql.connector.connect(**DB_CONFIG)
query = """
    SELECT 
        v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
        v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
        v21, v22, v23, v24, v25, v26, v27, v28,
        amount, is_fraud
    FROM Transactions
    WHERE amount > 800 AND is_fraud IS NOT NULL
    ORDER BY transaction_time DESC
    LIMIT 1000
"""
df = pd.read_sql(query, conn)
conn.close()

# Step 2: Check if enough fraud cases exist
if df['is_fraud'].sum() < 10:
    print("⚠️ WARNING: Not enough fraud samples for training. Model may underperform.")
else:
    print("✅ Loaded data. Fraud samples:", df['is_fraud'].sum())

# Step 3: Separate features and labels
X = df.drop(columns=['is_fraud'])
y = df['is_fraud']

# Step 4: Train/test split and SMOTE
X_train, X_test, y_train, y_test = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)

# Step 5: Balance classes with SMOTE
X_train_bal, y_train_bal = SMOTE(random_state=42).fit_resample(X_train, y_train)

# Step 6: Scale the features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train_bal)
X_test_scaled = scaler.transform(X_test)

# Step 7: Train the classifier
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train_scaled, y_train_bal)

# Step 8: Evaluate
y_pred = clf.predict(X_test_scaled)
print("✅ Model Evaluation:\n")
print(classification_report(y_test, y_pred))

# Step 9: Save the model and scaler
joblib.dump(clf, "fraud_model.pkl")
joblib.dump(scaler, "scaler.pkl")
print("✅ Model and scaler saved as 'fraud_model.pkl' and 'scaler.pkl'")


