import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import mysql.connector
from sqlalchemy import create_engine
from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import os
from io import BytesIO
import base64
import joblib
model = joblib.load('fraud_model.pkl')  # Load once

app = Flask(__name__)
app.secret_key = 'your_secret_key_here'  # Change this for production!

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'fraud_account',
    'password': 'secure_password125',
    'database': 'BankFraudDetection'
}


# User model for authentication
class User(UserMixin):
    def __init__(self, id):
        self.id = id


# Flask-Login setup
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
def plot_to_base64(fig):
    buf = BytesIO()
    fig.savefig(buf, format="png", bbox_inches="tight")
    plt.close(fig)
    return base64.b64encode(buf.getvalue()).decode("utf-8")

@login_manager.user_loader
def load_user(user_id):
    return User(user_id)


# Helper function to create database connection
def get_db_connection():
    return mysql.connector.connect(**DB_CONFIG)


# Helper function to plot to base64 for HTML
def plot_to_base64(fig):
    buf = BytesIO()
    fig.savefig(buf, format='png', bbox_inches='tight')
    plt.close(fig)
    return base64.b64encode(buf.getvalue()).decode('utf-8')


# Routes
@app.route('/')
@login_required
def dashboard():
    try:
        # Get basic stats
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Total transactions
        cursor.execute("SELECT COUNT(*) as total FROM Transactions")
        total_trans = cursor.fetchone()['total']

        # Fraud transactions
        cursor.execute("SELECT COUNT(*) as fraud FROM Transactions WHERE is_fraud = 1")
        fraud_trans = cursor.fetchone()['fraud']

        # Fraud percentage
        fraud_percent = (fraud_trans / total_trans) * 100 if total_trans > 0 else 0

        # Recent fraud alerts
        cursor.execute("""
            SELECT t.transaction_id, t.amount, t.transaction_date, 
                   c.first_name, c.last_name, r.rule_name, fa.status
            FROM FraudAlerts fa
            JOIN Transactions t ON fa.transaction_id = t.transaction_id
            JOIN Accounts a ON t.account_id = a.account_id
            JOIN Customers c ON a.customer_id = c.customer_id
            JOIN FraudRules r ON fa.rule_id = r.rule_id
            WHERE fa.status IN ('confirmed', 'investigating')
            ORDER BY t.transaction_date DESC
            LIMIT 5
        """)

        recent_alerts = cursor.fetchall()

        # Generate fraud vs legit plot
        cursor.execute("SELECT is_fraud FROM Transactions LIMIT 10000")
        df = pd.DataFrame(cursor.fetchall())
        counts = df['is_fraud'].value_counts()
        fig, ax = plt.subplots()
        sns.barplot(x=counts.index, y=counts.values, ax=ax)
        ax.set_xticklabels(['Legit', 'Fraud'])
        ax.set_title("Fraud vs Legit Transactions")
        fraud_plot = plot_to_base64(fig)

        # Generate amount distribution plot
        cursor.execute("SELECT amount, is_fraud FROM Transactions LIMIT 10000")
        df = pd.DataFrame(cursor.fetchall())
        fig, ax = plt.subplots(figsize=(10, 5))
        sns.histplot(df[df['is_fraud'] == 0]['amount'], bins=50, label="Legit",
                     color='green', log_scale=True, stat='density', ax=ax)
        sns.histplot(df[df['is_fraud'] == 1]['amount'], bins=50, label="Fraud",
                     color='red', log_scale=True, stat='density', ax=ax)
        ax.legend()
        ax.set_title("Transaction Amount Distribution (Log Scale)")
        amount_plot = plot_to_base64(fig)

        cursor.execute("SELECT COUNT(*) as investigating FROM FraudAlerts WHERE status = 'investigating'")
        investigating_alerts = cursor.fetchone()['investigating']
        # Count fraud alerts by status (for pie chart)
        cursor.execute("""
            SELECT status, COUNT(*) as count
            FROM FraudAlerts
            GROUP BY status
        """)
        status_data = cursor.fetchall()
        df_status = pd.DataFrame(status_data)
        fig, ax = plt.subplots()
        ax.pie(df_status['count'], labels=df_status['status'], autopct='%1.1f%%', startangle=140)
        ax.set_title("Fraud Alerts by Status")
        status_pie_plot = plot_to_base64(fig)
        cursor.execute("""
            SELECT r.rule_name, COUNT(*) as total_alerts
            FROM FraudAlerts fa
            JOIN FraudRules r ON fa.rule_id = r.rule_id
            GROUP BY fa.rule_id
        """)
        df_rules = pd.DataFrame(cursor.fetchall())

        fig, ax = plt.subplots()
        sns.barplot(data=df_rules, x='rule_name', y='total_alerts', ax=ax)
        ax.set_title("Fraud Alerts by Rule")
        ax.set_xticklabels(ax.get_xticklabels(), rotation=20)
        fraud_rule_plot = plot_to_base64(fig)
        cursor.execute("""
            SELECT r.severity, COUNT(*) as count
            FROM FraudAlerts fa
            JOIN FraudRules r ON fa.rule_id = r.rule_id
            GROUP BY r.severity
            ORDER BY r.severity
        """)
        df_severity = pd.DataFrame(cursor.fetchall())

        fig, ax = plt.subplots()
        ax.pie(df_severity['count'], labels=df_severity['severity'], autopct='%1.1f%%')
        ax.set_title("Fraud Alert Severity Distribution")
        severity_plot = plot_to_base64(fig)
        cursor.execute("""
            SELECT a.account_number, COUNT(*) as alert_count
            FROM FraudAlerts fa
            JOIN Transactions t ON fa.transaction_id = t.transaction_id
            JOIN Accounts a ON t.account_id = a.account_id
            GROUP BY a.account_number
            ORDER BY alert_count DESC
            LIMIT 10
        """)
        df_top_accounts = pd.DataFrame(cursor.fetchall())

        fig, ax = plt.subplots(figsize=(15, 6))
        sns.barplot(data=df_top_accounts, x='account_number', y='alert_count', ax=ax)
        ax.set_title("Top 10 Accounts with Most Fraud Alerts")
        top_account_plot = plot_to_base64(fig)
        # Query top 10 cities by fraud count
        cursor.execute("""
            SELECT c.city, COUNT(*) as fraud_count
            FROM Transactions t
            JOIN Accounts a ON t.account_id = a.account_id
            JOIN Customers c ON a.customer_id = c.customer_id
            WHERE t.is_fraud = 1
            GROUP BY c.city
            ORDER BY fraud_count DESC
            LIMIT 10
        """)
        city_data = cursor.fetchall()
        df_city = pd.DataFrame(city_data)

        # Plot: Top Cities by Fraud Count (Horizontal Bar)
        fig, ax = plt.subplots(figsize=(6, 4))
        sns.barplot(y=df_city['city'], x=df_city['fraud_count'], ax=ax)
        ax.set_title("Top Cities by Fraud Count")
        ax.set_xlabel("Fraud Count")
        city_fraud_plot = plot_to_base64(fig)

        # Generate correlation matrix for high amount transactions
        cursor.execute("SELECT * FROM Transactions WHERE amount > 800")
        df_high = pd.DataFrame(cursor.fetchall())

        # Ensure columns are lower case to match keys
        df_high.columns = [col.lower() for col in df_high.columns]

        # Keep only V1–V28 and is_fraud
        corr_cols = ['v' + str(i) for i in range(1, 29)] + ['is_fraud']
        df_high = df_high[corr_cols]

        # Compute correlation matrix
        corr = df_high.corr()

        # Plot correlation matrix
        fig, ax = plt.subplots(figsize=(10, 8))
        sns.heatmap(corr, cmap="coolwarm", center=0, ax=ax)
        ax.set_title("Feature Correlation Matrix (Amount > $800)")

        # Convert to base64
        correlation_plot = plot_to_base64(fig)  # make sure this matches the variable you use below

        cursor.close()
        conn.close()
        return render_template('dashboard.html',
                               total_trans=total_trans,
                               fraud_trans=fraud_trans,
                               fraud_percent=round(fraud_percent, 2),
                               recent_alerts=recent_alerts,
                               fraud_plot=fraud_plot,
                               amount_plot=amount_plot,
                               investigating_alerts=investigating_alerts,
                             status_pie_plot = status_pie_plot,
                               fraud_rule_plot=fraud_rule_plot,
                                severity_plot = severity_plot,
                               top_account_plot=top_account_plot,
                               city_fraud_plot=city_fraud_plot,
                               correlation_plot=correlation_plot
                               )

    except Exception as e:
        flash(f"Error loading dashboard: {str(e)}", "danger")
        return render_template('dashboard.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        # Simple authentication - in production, use proper password hashing!
        if username == 'admin' and password == 'admin123':  # Change these credentials!
            user = User(1)
            login_user(user)
            return redirect(url_for('dashboard'))
        else:
            flash('Invalid credentials', 'danger')

    return render_template('login.html')


@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))


@app.route('/transactions')
@login_required
def transactions():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        page = request.args.get('page', 1, type=int)
        per_page = 20
        offset = (page - 1) * per_page

        # Get transactions with pagination
        cursor.execute(f"""
            SELECT t.*, c.first_name, c.last_name, 
                   a.account_number, cc.card_number
            FROM Transactions t
            JOIN Accounts a ON t.account_id = a.account_id
            JOIN Customers c ON a.customer_id = c.customer_id
            JOIN CreditCards cc ON t.card_id = cc.card_id
            ORDER BY t.transaction_date DESC
            LIMIT {per_page} OFFSET {offset}
        """)
        transactions = cursor.fetchall()

        # Get total count for pagination
        cursor.execute("SELECT COUNT(*) as total FROM Transactions")
        total = cursor.fetchone()['total']

        cursor.close()
        conn.close()

        return render_template(
            'transactions.html',
            transactions=transactions,
            page=page,
            per_page=per_page,
            total=total
        )

    except Exception as e:
        flash(f"Error loading transactions: {str(e)}", "danger")
        return render_template('transactions.html')


@app.route('/fraud-alerts')
@login_required
def fraud_alerts():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        status = request.args.get('status', 'new')
        page = request.args.get('page', 1, type=int)
        per_page = 60
        offset = (page - 1) * per_page

        if status == 'new':
            cursor.execute(f"""
                SELECT SQL_CALC_FOUND_ROWS fa.*, t.amount, t.transaction_date,
                       r.rule_name, r.description, r.severity,
                       c.first_name, c.last_name, a.account_number
                FROM FraudAlerts fa
                JOIN Transactions t ON fa.transaction_id = t.transaction_id
                JOIN FraudRules r ON fa.rule_id = r.rule_id
                JOIN Accounts a ON t.account_id = a.account_id
                JOIN Customers c ON a.customer_id = c.customer_id
                WHERE fa.status IN ('confirmed', 'investigating')
                ORDER BY fa.alert_date DESC
                LIMIT {per_page} OFFSET {offset}
            """)
        else:
            cursor.execute(f"""
                SELECT SQL_CALC_FOUND_ROWS fa.*, t.amount, t.transaction_date,
                       r.rule_name, r.description, r.severity,
                       c.first_name, c.last_name, a.account_number
                FROM FraudAlerts fa
                JOIN Transactions t ON fa.transaction_id = t.transaction_id
                JOIN FraudRules r ON fa.rule_id = r.rule_id
                JOIN Accounts a ON t.account_id = a.account_id
                JOIN Customers c ON a.customer_id = c.customer_id
                WHERE fa.status = %s
                ORDER BY fa.alert_date DESC
                LIMIT {per_page} OFFSET {offset}
            """, (status,))

        alerts = cursor.fetchall()

        # Get total rows (use FOUND_ROWS)
        cursor.execute("SELECT FOUND_ROWS() as total")
        total = cursor.fetchone()['total']

        cursor.close()
        conn.close()

        return render_template('fraud_alerts.html',
                               alerts=alerts,
                               status=status,
                               page=page,
                               per_page=per_page,
                               total=total)

    except Exception as e:
        print("❌ Error loading fraud alerts:", str(e))
        flash(f"Error loading fraud alerts: {str(e)}", "danger")
        return render_template('fraud_alerts.html')




@app.route('/update-alert/<int:alert_id>', methods=['POST'])
@login_required
def update_alert(alert_id):
    try:
        new_status = request.form['status']
        notes = request.form.get('notes', '')

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            UPDATE FraudAlerts
            SET status = %s, notes = %s
            WHERE alert_id = %s
        """, (new_status, notes, alert_id))

        conn.commit()
        cursor.close()
        conn.close()

        flash('Alert updated successfully', 'success')
        return redirect(url_for('fraud_alerts'))

    except Exception as e:
        flash(f"Error updating alert: {str(e)}", "danger")
        return redirect(url_for('fraud_alerts'))

@app.route('/load-data', methods=['GET', 'POST'])
@login_required
def load_data():
    if request.method == 'POST':
        if 'file' not in request.files:
            flash('No file selected', 'danger')
            return redirect(request.url)

        file = request.files['file']
        if file.filename == '':
            flash('No file selected', 'danger')
            return redirect(request.url)

        if file and file.filename.endswith('.csv'):
            try:
                filepath = os.path.join('temp', file.filename)
                file.save(filepath)

                df = pd.read_csv(filepath, nrows=1000)
                df = df.dropna()

                # Rename and standardize column names
                df.rename(columns={'Time': 'transaction_time', 'Class': 'is_fraud'}, inplace=True)
                df.columns = [col.lower() for col in df.columns]

                # Validate columns
                kaggle_features = ['transaction_time', 'amount'] + [f'v{i}' for i in range(1, 29)] + ['is_fraud']
                for col in kaggle_features:
                    if col not in df.columns:
                        raise Exception(f"❌ Missing column in CSV: {col}")

                # Connect to DB
                conn = get_db_connection()
                conn.autocommit = False  # Explicitly manage transactions
                cursor = conn.cursor()

                # Get all available account/card pairs
                cursor.execute("""
                    SELECT a.account_id, c.card_id
                    FROM Accounts a
                    JOIN CreditCards c ON a.account_id = c.account_id
                """)
                account_card_pairs = cursor.fetchall()

                if not account_card_pairs:
                    raise Exception("❌ No account/card pairs available in the database.")

                # Repeat account/card pairs if needed
                import random
                while len(account_card_pairs) < len(df):
                    account_card_pairs += random.sample(account_card_pairs, len(account_card_pairs))
                account_card_pairs = account_card_pairs[:len(df)]

                acc_df = pd.DataFrame(account_card_pairs, columns=['account_id', 'card_id']).reset_index(drop=True)
                df = df.reset_index(drop=True)
                full_data = pd.concat([acc_df, df], axis=1)

                # Final column list (33 columns)
                expected_cols = ['account_id', 'card_id', 'transaction_time', 'amount'] + \
                                [f'v{i}' for i in range(1, 29)] + ['is_fraud']

                missing = [col for col in expected_cols if col not in full_data.columns]
                if missing:
                    raise Exception(f"❌ Final dataset missing columns: {missing}")

                full_data = full_data.where(pd.notnull(full_data), None)
                values = [tuple(row) for row in full_data[expected_cols].values]

                insert_sql = """
                    INSERT INTO Transactions (
                        account_id, card_id, transaction_time, amount,
                        v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
                        v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
                        v21, v22, v23, v24, v25, v26, v27, v28, is_fraud
                    ) VALUES (
                        %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                """

                # ✅ Batch insert in chunks of 100
                batch_size = 100
                for i in range(0, len(values), batch_size):
                    sub_batch = values[i:i + batch_size]
                    try:
                        cursor.executemany(insert_sql, sub_batch)
                        conn.commit()
                        print(f"✅ Batch {i // batch_size + 1}: Inserted {len(sub_batch)} transactions.")
                    except mysql.connector.Error as e:
                        conn.rollback()
                        print(f"❌ Batch {i // batch_size + 1} failed: {e}")
                        flash(f"❌ Batch insert failed: {str(e)}", 'danger')
                        break

                cursor.close()
                conn.close()
                os.remove(filepath)

                flash(f"✅ Successfully loaded {len(values)} transactions.", 'success')
                return redirect(url_for('dashboard'))

            except Exception as e:
                flash(f"❌ Error loading data: {str(e)}", 'danger')
                return redirect(request.url)

        else:
            flash('❌ Only CSV files are allowed', 'danger')
            return redirect(request.url)

    return render_template('load_data.html')



# Run fraud detection
@app.route('/run-detection')
@login_required
def run_detection():
    import time, os
    import pandas as pd
    from joblib import load

    start = time.time()
    try:
        BASE_DIR = os.path.dirname(os.path.abspath(__file__))
        model = load(os.path.join(BASE_DIR, "fraud_model.pkl"))

        # Try to load scaler
        try:
            scaler = load(os.path.join(BASE_DIR, "scaler.pkl"))
            use_scaler = True
        except FileNotFoundError:
            print("⚠️ No scaler found. Using unscaled input.")
            use_scaler = False
            scaler = None

        # Connect to DB and extend timeout
        conn = get_db_connection()
        conn.autocommit = True
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SET innodb_lock_wait_timeout = 120;")

        # Clear temporary alerts
        cursor.execute("DELETE FROM FraudAlerts WHERE status = 'temporary'")

        # Rule-based alerts (Amount > 800)
        cursor.execute("""
            INSERT IGNORE INTO FraudAlerts (transaction_id, rule_id, status)
            SELECT t.transaction_id, 1, 'new'
            FROM (
                SELECT * FROM Transactions ORDER BY transaction_time DESC LIMIT 1000
            ) t
            WHERE t.amount > 800
              AND NOT EXISTS (
                SELECT 1 FROM FraudAlerts fa
                WHERE fa.transaction_id = t.transaction_id AND fa.rule_id = 1
              )
        """)

        # Load data for ML
        cursor.execute("""
            SELECT transaction_id, amount,
                   v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
                   v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
                   v21, v22, v23, v24, v25, v26, v27, v28
            FROM Transactions
            ORDER BY transaction_time DESC
            LIMIT 1000
        """)
        rows = cursor.fetchall()
        if not rows:
            flash("⚠️ No transactions to analyze.", "warning")
            return redirect(url_for('dashboard'))

        # Create DataFrame with correct lowercase columns
        df = pd.DataFrame(rows)
        df.columns = [col.lower() for col in df.columns]

        X = df[[f'v{i}' for i in range(1, 29)] + ['amount']]

        if use_scaler:
            X_scaled = scaler.transform(X)
        else:
            X_scaled = X

        preds = model.predict(X_scaled)
        probs = model.predict_proba(X_scaled)[:, 1]

        update_data = []
        flagged_ml = []

        for idx, row in df.iterrows():
            tx_id = int(row['transaction_id'])
            amount = float(row['amount'])
            prediction = int(preds[idx])
            confidence = float(probs[idx])

            print(f"🔍 TX {tx_id} | ${amount:.2f} | ML_PRED: {prediction} | CONF: {confidence:.4f}")

            update_data.append((prediction, confidence, tx_id))

            if prediction == 1 and confidence >= 0.8:
                flagged_ml.append((tx_id, 99, 'ml_fraud'))

        # Update ML results
        for i in range(0, len(update_data), 25):
            cursor.executemany("""
                UPDATE Transactions
                SET ml_prediction = %s, ml_confidence = %s
                WHERE transaction_id = %s
            """, update_data[i:i + 25])

        # Insert ML alerts
        if flagged_ml:
            for i in range(0, len(flagged_ml), 25):
                cursor.executemany("""
                    INSERT IGNORE INTO FraudAlerts (transaction_id, rule_id, status)
                    VALUES (%s, %s, %s)
                """, flagged_ml[i:i + 25])

        cursor.close()
        conn.close()

        runtime = time.time() - start
        flash(f"✅ Detection complete: Rule + {len(flagged_ml)} ML alerts in {runtime:.2f}s", "success")
        return redirect(url_for('fraud_alerts'))

    except Exception as e:
        flash(f"❌ Detection failed: {str(e)}", "danger")
        return redirect(url_for('dashboard'))



@app.route('/predict-transaction/<int:transaction_id>')
@login_required
def predict_transaction(transaction_id):
    page = request.args.get('page', 1, type=int)
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT * FROM Transactions WHERE transaction_id = %s", (transaction_id,))
        tx = cursor.fetchone()
        cursor.close()
        conn.close()

        if not tx:
            flash('Transaction not found', 'danger')
            return redirect(url_for('transactions', page=page))

        features = [tx[f'v{i}'] for i in range(1, 29)] + [tx['amount']]

        print("🧪 Features:", features)
        print("🧪 Length of feature vector:", len(features))

        prediction = model.predict([features])[0]
        prob = model.predict_proba([features])[0]

        print("🔍 Prediction Probabilities:", prob)  # <-- This should show [0.92, 0.08] etc

        msg = f"Prediction for Transaction #{transaction_id}: "
        msg += f"<strong>{'FRAUD' if prediction == 1 else 'LEGIT'}</strong> "
        msg += f"(Confidence: {prob[1]:.2%})"
        flash(msg, 'info')

    except Exception as e:
        flash(f"Error during prediction: {str(e)}", "danger")

    return redirect(url_for('transactions', page=page))



if __name__ == '__main__':
    # Create temp directory if it doesn't exist
    if not os.path.exists('temp'):
        os.makedirs('temp')

    # Create templates directory if it doesn't exist
    if not os.path.exists('templates'):
        os.makedirs('templates')
        # You would need to create your HTML templates here

    app.run(debug=True)