
-- 1. SETUP SERVER CONFIGURATION (run once)
-- 1. SETUP SERVER CONFIGURATION (run first)
SET GLOBAL wait_timeout = 28800;  -- 8 hours in seconds
SET GLOBAL interactive_timeout = 28800;
SET GLOBAL max_allowed_packet = 268435456;  -- 256MB in bytes (256*1024*1024)

-- 2. CREATE USER AND DATABASE
DROP USER IF EXISTS 'fraud_account'@'localhost';
CREATE USER 'fraud_account'@'localhost' IDENTIFIED BY 'secure_password125';
GRANT ALL PRIVILEGES ON BankFraudDetection.* TO 'fraud_account'@'localhost';
FLUSH PRIVILEGES;

-- 3. CREATE DATABASE
DROP DATABASE IF EXISTS BankFraudDetection;
CREATE DATABASE BankFraudDetection CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE BankFraudDetection;

-- 3. CREATE TABLES WITH OPTIMIZED STRUCTURE
CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    registration_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_customer_name (last_name, first_name)
) ENGINE=InnoDB;

CREATE TABLE Accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    account_type ENUM('checking', 'savings', 'credit') NOT NULL,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    balance DECIMAL(15, 2) DEFAULT 0.00,
    open_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('active', 'inactive', 'closed') DEFAULT 'active',
    credit_limit DECIMAL(15, 2) DEFAULT 0.00,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    INDEX idx_account_type (account_type)
) ENGINE=InnoDB;

CREATE TABLE CreditCards (
    card_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    card_number VARCHAR(20) UNIQUE NOT NULL,
    expiry_date DATE NOT NULL,
    cvv VARCHAR(5) NOT NULL,
    issue_date DATE DEFAULT (CURRENT_DATE),
    status ENUM('active', 'inactive', 'lost', 'stolen') DEFAULT 'active',
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
    INDEX idx_card_number (card_number)
) ENGINE=InnoDB;

CREATE TABLE Transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    card_id INT NOT NULL,
    transaction_time INT NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    v1 DECIMAL(12, 6) NOT NULL,
    v2 DECIMAL(12, 6) NOT NULL,
    v3 DECIMAL(12, 6) NOT NULL,
    v4 DECIMAL(12, 6) NOT NULL,
    v5 DECIMAL(12, 6) NOT NULL,
    v6 DECIMAL(12, 6) NOT NULL,
    v7 DECIMAL(12, 6) NOT NULL,
    v8 DECIMAL(12, 6) NOT NULL,
    v9 DECIMAL(12, 6) NOT NULL,
    v10 DECIMAL(12, 6) NOT NULL,
    v11 DECIMAL(12, 6) NOT NULL,
    v12 DECIMAL(12, 6) NOT NULL,
    v13 DECIMAL(12, 6) NOT NULL,
    v14 DECIMAL(12, 6) NOT NULL,
    v15 DECIMAL(12, 6) NOT NULL,
    v16 DECIMAL(12, 6) NOT NULL,
    v17 DECIMAL(12, 6) NOT NULL,
    v18 DECIMAL(12, 6) NOT NULL,
    v19 DECIMAL(12, 6) NOT NULL,
    v20 DECIMAL(12, 6) NOT NULL,
    v21 DECIMAL(12, 6) NOT NULL,
    v22 DECIMAL(12, 6) NOT NULL,
    v23 DECIMAL(12, 6) NOT NULL,
    v24 DECIMAL(12, 6) NOT NULL,
    v25 DECIMAL(12, 6) NOT NULL,
    v26 DECIMAL(12, 6) NOT NULL,
    v27 DECIMAL(12, 6) NOT NULL,
    v28 DECIMAL(12, 6) NOT NULL,
    is_fraud BOOLEAN NOT NULL,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
    FOREIGN KEY (card_id) REFERENCES CreditCards(card_id),
    INDEX idx_transaction_date (transaction_date),
    INDEX idx_amount (amount),
    INDEX idx_is_fraud (is_fraud)
) ENGINE=InnoDB;

CREATE TABLE FraudRules (
    rule_id INT AUTO_INCREMENT PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    condition_sql TEXT NOT NULL,
    severity TINYINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_rule_active (is_active)
) ENGINE=InnoDB;

CREATE TABLE FraudAlerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT NOT NULL,
    rule_id INT NOT NULL,
    alert_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('new', 'investigating', 'confirmed', 'false_positive') DEFAULT 'new',
    notes TEXT,
    FOREIGN KEY (transaction_id) REFERENCES Transactions(transaction_id),
    FOREIGN KEY (rule_id) REFERENCES FraudRules(rule_id),
    INDEX idx_alert_status (status),
    INDEX idx_alert_date (alert_date)
) ENGINE=InnoDB;

-- 4. OPTIMIZED DATA GENERATION PROCEDURES
DELIMITER //

CREATE PROCEDURE GenerateRandomCustomers(IN total_count INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE batch_size INT DEFAULT 100;
    DECLARE batches INT DEFAULT total_count DIV batch_size;
    DECLARE remainder INT DEFAULT total_count MOD batch_size;
    DECLARE i INT DEFAULT 0;
    
    -- Temporary tables for names
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_first_names (name VARCHAR(50));
    INSERT INTO temp_first_names VALUES 
    ('James'),('Mary'),('John'),('Patricia'),('Robert'),('Jennifer'),('Michael'),('Linda'),
    ('William'),('Elizabeth'),('David'),('Barbara'),('Richard'),('Susan'),('Joseph'),('Jessica'),
    ('Thomas'),('Sarah'),('Charles'),('Karen'),('Christopher'),('Nancy'),('Daniel'),('Lisa'),
    ('Matthew'),('Margaret'),('Anthony'),('Betty'),('Donald'),('Sandra');
    
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_last_names (name VARCHAR(50));
    INSERT INTO temp_last_names VALUES 
    ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Miller'),('Davis'),
    ('Garcia'),('Rodriguez'),('Wilson'),('Martinez'),('Anderson'),('Taylor'),('Thomas'),
    ('Hernandez'),('Moore'),('Martin'),('Jackson'),('Thompson'),('White'),('Lopez'),('Lee'),
    ('Gonzalez'),('Harris'),('Clark'),('Lewis'),('Robinson'),('Walker'),('Perez'),('Hall');
    
    -- Process in batches
    WHILE i < batches AND NOT done DO
        BEGIN
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET done = TRUE;
            
            INSERT INTO Customers (first_name, last_name, email, phone, address, city, state, zip_code)
            SELECT 
                fn.name,
                ln.name,
                CONCAT(LCASE(fn.name), '.', LCASE(ln.name), FLOOR(RAND() * 1000000), '@example.com'),
                CONCAT('555-', LPAD(FLOOR(RAND() * 1000), 3, '0'), '-', LPAD(FLOOR(RAND() * 10000), 4, '0')),
                CONCAT(FLOOR(RAND() * 9999) + 1, ' ', ln.name, ' ', 
                      ELT(FLOOR(RAND() * 5) + 1, 'St', 'Ave', 'Blvd', 'Dr', 'Ln')),
                ELT(FLOOR(RAND() * 10) + 1, 'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 
                      'Philadelphia', 'San Antonio', 'Toronto', 'Dallas', 'Vancouver'),
                ELT(FLOOR(RAND() * 10) + 1, 'NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'ON', 'TX', 'BC'),
                LPAD(FLOOR(RAND() * 99999), 5, '0')
            FROM 
                (SELECT name FROM temp_first_names ORDER BY RAND() LIMIT batch_size) fn
                CROSS JOIN (SELECT name FROM temp_last_names ORDER BY RAND() LIMIT batch_size) ln
            LIMIT batch_size;
            
            SET i = i + 1;
        END;
    END WHILE;
    
    -- Process remainder
    IF remainder > 0 AND NOT done THEN
        INSERT INTO Customers (first_name, last_name, email, phone, address, city, state, zip_code)
        SELECT 
            fn.name,
            ln.name,
            CONCAT(LCASE(fn.name), '.', LCASE(ln.name), FLOOR(RAND() * 1000000), '@example.com'),
            CONCAT('555-', LPAD(FLOOR(RAND() * 1000), 3, '0'), '-', LPAD(FLOOR(RAND() * 10000), 4, '0')),
            CONCAT(FLOOR(RAND() * 9999) + 1, ' ', ln.name, ' ', 
                  ELT(FLOOR(RAND() * 5) + 1, 'St', 'Ave', 'Blvd', 'Dr', 'Ln')),
            ELT(FLOOR(RAND() * 10) + 1, 'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 
                  'Philadelphia', 'San Antonio', 'Toronto', 'Dallas', 'Vancouver'),
            ELT(FLOOR(RAND() * 10) + 1, 'NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'ON', 'TX', 'BC'),
            LPAD(FLOOR(RAND() * 99999), 5, '0')
        FROM 
            (SELECT name FROM temp_first_names ORDER BY RAND() LIMIT remainder) fn
            CROSS JOIN (SELECT name FROM temp_last_names ORDER BY RAND() LIMIT remainder) ln
        LIMIT remainder;
    END IF;
    
    DROP TEMPORARY TABLE temp_first_names;
    DROP TEMPORARY TABLE temp_last_names;
END //

CREATE PROCEDURE GenerateRandomAccounts(IN total_count INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE batch_size INT DEFAULT 100;
    DECLARE batches INT DEFAULT total_count DIV batch_size;
    DECLARE remainder INT DEFAULT total_count MOD batch_size;
    DECLARE i INT DEFAULT 0;
    
    -- Process in batches
    WHILE i < batches AND NOT done DO
        BEGIN
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET done = TRUE;
            
            INSERT INTO Accounts (customer_id, account_type, account_number, balance, credit_limit)
            SELECT 
                c.customer_id,
                CASE 
                    WHEN RAND() < 0.6 THEN 'checking'
                    WHEN RAND() < 0.8 THEN 'savings'
                    ELSE 'credit'
                END AS account_type,
                LPAD(FLOOR(RAND() * 10000000000), 10, '0'),
                ROUND(RAND() * 10000, 2),
                CASE 
                    WHEN RAND() < 0.2 THEN ROUND(5000 + RAND() * 15000, 2)
                    ELSE 0
                END
            FROM 
                (SELECT customer_id FROM Customers ORDER BY RAND() LIMIT batch_size) c;
            
            -- Add credit cards for credit accounts
            INSERT INTO CreditCards (account_id, card_number, expiry_date, cvv)
            SELECT 
                a.account_id,
                CONCAT('4', LPAD(FLOOR(RAND() * 1000000000000000), 15, '0')),
                DATE_ADD(CURRENT_DATE, INTERVAL 3 YEAR),
                LPAD(FLOOR(RAND() * 1000), 3, '0')
            FROM 
                Accounts a
            WHERE 
                a.account_type = 'credit' AND
                NOT EXISTS (SELECT 1 FROM CreditCards WHERE account_id = a.account_id)
            LIMIT 100;
            
            SET i = i + 1;
        END;
    END WHILE;
    
    -- Process remainder
    IF remainder > 0 AND NOT done THEN
        INSERT INTO Accounts (customer_id, account_type, account_number, balance, credit_limit)
        SELECT 
            c.customer_id,
            CASE 
                WHEN RAND() < 0.6 THEN 'checking'
                WHEN RAND() < 0.8 THEN 'savings'
                ELSE 'credit'
            END AS account_type,
            LPAD(FLOOR(RAND() * 10000000000), 10, '0'),
            ROUND(RAND() * 10000, 2),
            CASE 
                WHEN RAND() < 0.2 THEN ROUND(5000 + RAND() * 15000, 2)
                ELSE 0
            END
        FROM 
            (SELECT customer_id FROM Customers ORDER BY RAND() LIMIT remainder) c;
        
        -- Add credit cards for credit accounts
        INSERT INTO CreditCards (account_id, card_number, expiry_date, cvv)
        SELECT 
            a.account_id,
            CONCAT('4', LPAD(FLOOR(RAND() * 1000000000000000), 15, '0')),
            DATE_ADD(CURRENT_DATE, INTERVAL 3 YEAR),
            LPAD(FLOOR(RAND() * 1000), 3, '0')
        FROM 
            Accounts a
        WHERE 
            a.account_type = 'credit' AND
            NOT EXISTS (SELECT 1 FROM CreditCards WHERE account_id = a.account_id)
        LIMIT remainder;
    END IF;
END //

DELIMITER ;
DROP TABLE IF EXISTS kaggle_raw_data;

CREATE TABLE kaggle_raw_data (
    Time INT,
    V1 DECIMAL(12,6), V2 DECIMAL(12,6), V3 DECIMAL(12,6), V4 DECIMAL(12,6),
    V5 DECIMAL(12,6), V6 DECIMAL(12,6), V7 DECIMAL(12,6), V8 DECIMAL(12,6),
    V9 DECIMAL(12,6), V10 DECIMAL(12,6), V11 DECIMAL(12,6), V12 DECIMAL(12,6),
    V13 DECIMAL(12,6), V14 DECIMAL(12,6), V15 DECIMAL(12,6), V16 DECIMAL(12,6),
    V17 DECIMAL(12,6), V18 DECIMAL(12,6), V19 DECIMAL(12,6), V20 DECIMAL(12,6),
    V21 DECIMAL(12,6), V22 DECIMAL(12,6), V23 DECIMAL(12,6), V24 DECIMAL(12,6),
    V25 DECIMAL(12,6), V26 DECIMAL(12,6), V27 DECIMAL(12,6), V28 DECIMAL(12,6),
    Amount DECIMAL(15,2),
    Class INT
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/creditcard.csv'
INTO TABLE kaggle_raw_data
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Time, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10,
 V11, V12, V13, V14, V15, V16, V17, V18, V19, V20,
 V21, V22, V23, V24, V25, V26, V27, V28, Amount, Class);
 -- Check the structure of your kaggle_raw_data table
DESCRIBE kaggle_raw_data;

-- Check the structure of your Transactions table
DESCRIBE Transactions;

-- Check sample data from kaggle_raw_data
SELECT * FROM kaggle_raw_data LIMIT 5;
-- 5. LOAD KAGGLE DATA (run separately after account generation)
DELIMITER //

USE BankFraudDetection;

USE BankFraudDetection;
DELIMITER //

CREATE PROCEDURE LoadKaggleData(IN csv_path VARCHAR(255), IN batch_size INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE total_rows INT;
    DECLARE processed_rows INT DEFAULT 0;

    -- Create temporary table for staging
    CREATE TEMPORARY TABLE temp_kaggle_data (
        Time INT,
        V1 DECIMAL(12,6),
        V2 DECIMAL(12,6),
        V3 DECIMAL(12,6),
        V4 DECIMAL(12,6),
        V5 DECIMAL(12,6),
        V6 DECIMAL(12,6),
        V7 DECIMAL(12,6),
        V8 DECIMAL(12,6),
        V9 DECIMAL(12,6),
        V10 DECIMAL(12,6),
        V11 DECIMAL(12,6),
        V12 DECIMAL(12,6),
        V13 DECIMAL(12,6),
        V14 DECIMAL(12,6),
        V15 DECIMAL(12,6),
        V16 DECIMAL(12,6),
        V17 DECIMAL(12,6),
        V18 DECIMAL(12,6),
        V19 DECIMAL(12,6),
        V20 DECIMAL(12,6),
        V21 DECIMAL(12,6),
        V22 DECIMAL(12,6),
        V23 DECIMAL(12,6),
        V24 DECIMAL(12,6),
        V25 DECIMAL(12,6),
        V26 DECIMAL(12,6),
        V27 DECIMAL(12,6),
        V28 DECIMAL(12,6),
        Amount DECIMAL(15,2),
        Class INT
    );

    -- Load CSV
    SET @load_sql = CONCAT(
        "LOAD DATA INFILE '", csv_path, "' INTO TABLE temp_kaggle_data ",
        "FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' ",
        "LINES TERMINATED BY '\\n' IGNORE 1 ROWS ",
        "(Time, V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, ",
        "V11, V12, V13, V14, V15, V16, V17, V18, V19, V20, ",
        "V21, V22, V23, V24, V25, V26, V27, V28, Amount, Class)"
    );

    PREPARE stmt FROM @load_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Get row count
    SELECT COUNT(*) INTO total_rows FROM temp_kaggle_data;

    -- Insert in batches
    WHILE processed_rows < total_rows AND NOT done DO
        BEGIN
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET done = TRUE;

            INSERT INTO Transactions (
                account_id, card_id, transaction_time, amount,
                v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
                v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
                v21, v22, v23, v24, v25, v26, v27, v28, is_fraud
            )
            SELECT 
                a.account_id,
                c.card_id,
                k.Time,
                k.Amount,
                k.V1, k.V2, k.V3, k.V4, k.V5, k.V6, k.V7, k.V8, k.V9, k.V10,
                k.V11, k.V12, k.V13, k.V14, k.V15, k.V16, k.V17, k.V18, k.V19, k.V20,
                k.V21, k.V22, k.V23, k.V24, k.V25, k.V26, k.V27, k.V28,
                k.Class
            FROM 
                temp_kaggle_data k
                JOIN (SELECT account_id FROM Accounts ORDER BY RAND() LIMIT batch_size) a
                JOIN CreditCards c ON a.account_id = c.account_id
            LIMIT batch_size
            OFFSET processed_rows;

            SET processed_rows = processed_rows + batch_size;
        END;
    END WHILE;

    DROP TEMPORARY TABLE temp_kaggle_data;
END //

DELIMITER //


CREATE PROCEDURE LoadKaggleToTransactions(IN batch_size INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE total_rows INT;
    DECLARE processed_rows INT DEFAULT 0;

    SELECT COUNT(*) INTO total_rows FROM kaggle_raw_data;

    WHILE processed_rows < total_rows AND NOT done DO
        BEGIN
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET done = TRUE;

            INSERT INTO Transactions (
                account_id, card_id, transaction_time, amount,
                v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
                v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
                v21, v22, v23, v24, v25, v26, v27, v28, is_fraud
            )
            SELECT 
                ac.account_id,
                ac.card_id,
                k.Time,
                k.Amount,
                k.V1, k.V2, k.V3, k.V4, k.V5, k.V6, k.V7, k.V8, k.V9, k.V10,
                k.V11, k.V12, k.V13, k.V14, k.V15, k.V16, k.V17, k.V18, k.V19, k.V20,
                k.V21, k.V22, k.V23, k.V24, k.V25, k.V26, k.V27, k.V28,
                k.Class
            FROM kaggle_raw_data k
            JOIN (
                SELECT a.account_id, c.card_id
                FROM Accounts a
                JOIN CreditCards c ON a.account_id = c.account_id
                ORDER BY RAND()
                LIMIT batch_size
            ) AS ac
            LIMIT batch_size OFFSET processed_rows;

            SET processed_rows = processed_rows + batch_size;
        END;
    END WHILE;
END //

DELIMITER ;

DELIMITER ;
-- Run it
CALL LoadKaggleToTransactions(1000);
SHOW VARIABLES LIKE 'secure_file_priv';
DELIMITER ;

-- 6. EXECUTE DATA GENERATION (run these one at a time)
CALL GenerateRandomCustomers(1000);
CALL GenerateRandomAccounts(3000);
-- Add basic fraud detection rules
INSERT INTO FraudRules (rule_name, description, condition_sql, severity)
VALUES
('Large Transaction', 'Single transaction over $10,000', 
 'amount > 10000', 3),

('Rapid Successive Transactions', 'Multiple transactions within 10 minutes', 
 '(SELECT COUNT(*) FROM Transactions t2 
   WHERE t2.account_id = Transactions.account_id 
   AND t2.transaction_id != Transactions.transaction_id 
   AND ABS(t2.transaction_time - Transactions.transaction_time) < 600) >= 3', 4),

('Unusual Location Pattern', 'Geographically impossible transactions', 
 'EXISTS (SELECT 1 FROM Transactions t2 
   WHERE t2.card_id = Transactions.card_id
   AND t2.transaction_id != Transactions.transaction_id
   AND ABS(t2.transaction_time - Transactions.transaction_time) < 3600
   AND ABS(t2.v14 - Transactions.v14) > 5)', 5);
DELIMITER //

CREATE PROCEDURE RunFraudDetection()
BEGIN
    -- Clear previous temporary alerts
    DELETE FROM FraudAlerts WHERE status = 'temporary';
    
    -- Check each active rule
    INSERT INTO FraudAlerts (transaction_id, rule_id, status)
    SELECT t.transaction_id, r.rule_id, 'temporary'
    FROM Transactions t
    JOIN FraudRules r ON r.is_active = TRUE
    WHERE 
        CASE r.rule_id
            WHEN 1 THEN t.amount > 500
            WHEN 2 THEN (
                SELECT COUNT(*) FROM Transactions t2 
                WHERE t2.account_id = t.account_id
                AND t2.transaction_id != t.transaction_id
                AND ABS(t2.transaction_time - t.transaction_time) < 60
            ) >= 3
            WHEN 3 THEN EXISTS (
                SELECT 1 FROM Transactions t2 
                WHERE t2.card_id = t.card_id
                AND t2.transaction_id != t.transaction_id
                AND ABS(t2.transaction_time - t.transaction_time) < 360
                AND ABS(t2.v14 - t.v14) > 5
            )
        END
        AND NOT EXISTS (
            SELECT 1 FROM FraudAlerts fa
            WHERE fa.transaction_id = t.transaction_id
            AND fa.rule_id = r.rule_id
        );
    
    -- Update status of new alerts
    UPDATE FraudAlerts SET status = 'new' WHERE status = 'temporary';
    
    SELECT CONCAT(COUNT(*), ' new fraud alerts generated') AS result
    FROM FraudAlerts 
    WHERE status = 'new';
END //

DELIMITER ;
CREATE VIEW DailyFraudSummary AS
SELECT 
    DATE(transaction_date) AS day,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS confirmed_fraud,
    SUM(CASE WHEN fa.alert_id IS NOT NULL THEN 1 ELSE 0 END) AS suspected_fraud,
    SUM(amount) AS total_amount
FROM Transactions t
LEFT JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id
GROUP BY DATE(transaction_date);

-- High Risk Customers View
CREATE VIEW HighRiskCustomers AS
SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(fa.alert_id) AS alert_count,
    SUM(t.amount) AS total_suspicious_amount
FROM Customers c
JOIN Accounts a ON c.customer_id = a.customer_id
JOIN Transactions t ON a.account_id = t.account_id
JOIN FraudAlerts fa ON t.transaction_id = fa.transaction_id
GROUP BY c.customer_id, customer_name
HAVING COUNT(fa.alert_id) > 3
ORDER BY alert_count DESC;
SET GLOBAL event_scheduler = ON;

DELIMITER //

CREATE EVENT IF NOT EXISTS DailyFraudCheck
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MINUTE  -- Starts 1 minute from now
COMMENT 'Daily fraud detection job'
DO
BEGIN
    DECLARE alert_count INT;
    
    -- Run fraud detection
    CALL RunFraudDetection();
    
    -- Get count of new alerts
    SELECT COUNT(*) INTO alert_count
    FROM FraudAlerts
    WHERE status = 'new' 
    AND alert_date >= DATE_SUB(NOW(), INTERVAL 1 DAY);
    
    -- Only notify if alerts found
    IF alert_count > 0 THEN
        INSERT INTO NotificationQueue (message)
        VALUES (CONCAT('Daily Fraud Check: ', alert_count, ' new alerts detected'));
    END IF;
    
    -- Optional: Update last run time in config table
    INSERT INTO SystemConfig (config_key, config_value, updated_at)
    VALUES ('last_fraud_check', NOW(), NOW())
    ON DUPLICATE KEY UPDATE config_value = NOW(), updated_at = NOW();
END //
DELIMITER ;
SELECT COUNT(*) FROM Transactions;
SELECT * FROM Transactions LIMIT 10;
SELECT is_fraud, COUNT(*) AS total FROM Transactions GROUP BY is_fraud;
SELECT a.account_id, c.card_id
FROM Accounts a
JOIN CreditCards c ON a.account_id = c.account_id
LIMIT 5;
INSERT INTO Transactions (
    account_id, card_id, transaction_time, amount,
    v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
    v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
    v21, v22, v23, v24, v25, v26, v27, v28, is_fraud
)
SELECT 
    a.account_id,
    c.card_id,
    k.Time,
    k.Amount,
    k.V1, k.V2, k.V3, k.V4, k.V5, k.V6, k.V7, k.V8, k.V9, k.V10,
    k.V11, k.V12, k.V13, k.V14, k.V15, k.V16, k.V17, k.V18, k.V19, k.V20,
    k.V21, k.V22, k.V23, k.V24, k.V25, k.V26, k.V27, k.V28,
    k.Class
FROM kaggle_raw_data k
JOIN (SELECT account_id FROM Accounts ORDER BY RAND() LIMIT 1000) a
JOIN CreditCards c ON a.account_id = c.account_id
LIMIT 1000;
SELECT 
    ac.account_id, ac.card_id,
    k.Time, k.Amount, k.Class
FROM kaggle_raw_data k
JOIN (
    SELECT a.account_id, c.card_id
    FROM Accounts a
    JOIN CreditCards c ON a.account_id = c.account_id
    ORDER BY RAND()
    LIMIT 10
) AS ac
LIMIT 10;
INSERT INTO Transactions (
    account_id, card_id, transaction_time, amount,
    v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
    v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
    v21, v22, v23, v24, v25, v26, v27, v28, is_fraud
)
SELECT 
    ac.account_id,
    ac.card_id,
    k.Time,
    k.Amount,
    k.V1, k.V2, k.V3, k.V4, k.V5, k.V6, k.V7, k.V8, k.V9, k.V10,
    k.V11, k.V12, k.V13, k.V14, k.V15, k.V16, k.V17, k.V18, k.V19, k.V20,
    k.V21, k.V22, k.V23, k.V24, k.V25, k.V26, k.V27, k.V28,
    k.Class
FROM kaggle_raw_data k
JOIN (
    SELECT a.account_id, c.card_id
    FROM Accounts a
    JOIN CreditCards c ON a.account_id = c.account_id
    ORDER BY RAND()
    LIMIT 1000
) AS ac
LIMIT 1000;
DROP PROCEDURE IF EXISTS LoadFullKaggleDataset;
DELIMITER //

CREATE PROCEDURE LoadFullKaggleDataset(IN batch_size INT)
BEGIN
    DECLARE total_rows INT;
    DECLARE processed_rows INT DEFAULT 0;
    DECLARE done INT DEFAULT FALSE;

    -- Get total rows from kaggle_raw_data
    SELECT COUNT(*) INTO total_rows FROM kaggle_raw_data;

    WHILE processed_rows < total_rows AND NOT done DO
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET done = TRUE;

        INSERT INTO Transactions (
            account_id, card_id, transaction_time, amount,
            v1, v2, v3, v4, v5, v6, v7, v8, v9, v10,
            v11, v12, v13, v14, v15, v16, v17, v18, v19, v20,
            v21, v22, v23, v24, v25, v26, v27, v28, is_fraud
        )
        SELECT 
            ac.account_id,
            ac.card_id,
            k.Time,
            k.Amount,
            k.V1, k.V2, k.V3, k.V4, k.V5, k.V6, k.V7, k.V8, k.V9, k.V10,
            k.V11, k.V12, k.V13, k.V14, k.V15, k.V16, k.V17, k.V18, k.V19, k.V20,
            k.V21, k.V22, k.V23, k.V24, k.V25, k.V26, k.V27, k.V28,
            k.Class
        FROM kaggle_raw_data k
        JOIN (
            SELECT a.account_id, c.card_id
            FROM Accounts a
            JOIN CreditCards c ON a.account_id = c.account_id
            ORDER BY RAND()
            LIMIT batch_size
        ) AS ac
        LIMIT batch_size OFFSET processed_rows;

        SET processed_rows = processed_rows + batch_size;
    END;
    END WHILE;
END //

DELIMITER ;
CALL LoadFullKaggleDataset(1000);
-- Total inserted
SELECT COUNT(*) FROM Transactions;

-- Check sample
SELECT * FROM Transactions ORDER BY transaction_id DESC LIMIT 100;

-- Fraud breakdown
SELECT * FROM Transactions
WHERE is_fraud = 1
LIMIT 400;
ALTER TABLE FraudRules
DROP CHECK fraudrules_chk_1;
-- Then re-add with updated limit (e.g., up to 10):
ALTER TABLE FraudRules
ADD CONSTRAINT fraudrules_chk_1 CHECK (severity BETWEEN 1 AND 10);
-- 1. Upsert Rules
INSERT INTO FraudRules (rule_id, rule_name, description, condition_sql, severity, is_active)
VALUES 
    (1, 'Confirmed is_fraud', 'Transaction labeled fraud by system (is_fraud = 1)', 't.is_fraud = 1', 5, TRUE),
    (2, 'V14 Rule', 'V14 < -3.5', 't.v14 < -3.5', 4, TRUE),
    (3, 'V17 Rule', 'V17 < -2.5', 't.v17 < -2.5', 3, TRUE),
    (4, 'V12 Rule', 'V12 < -2.0', 't.v12 < -2.0', 2, TRUE),
    (5, 'V10 Rule', 'V10 < -2.0', 't.v10 < -2.0', 1, TRUE),
    (6, 'High Amount Rule', 'Transaction amount exceeds $800', 't.amount > 800', 6, TRUE)
ON DUPLICATE KEY UPDATE
    rule_name = VALUES(rule_name),
    description = VALUES(description),
    condition_sql = VALUES(condition_sql),
    severity = VALUES(severity),
    is_active = VALUES(is_active);

-- 2. Confirmed Alerts (is_fraud = 1)
INSERT INTO FraudAlerts (transaction_id, rule_id, status)
SELECT t.transaction_id, 1, 'confirmed'
FROM Transactions t
WHERE t.is_fraud = 1
  AND NOT EXISTS (
    SELECT 1 FROM FraudAlerts fa 
    WHERE fa.transaction_id = t.transaction_id AND fa.rule_id = 1
);

-- 3. Investigating Alerts (each rule)
INSERT INTO FraudAlerts (transaction_id, rule_id, status)
SELECT t.transaction_id, 2, 'investigating'
FROM Transactions t
WHERE t.is_fraud = 0 AND t.v14 < -3.5
  AND NOT EXISTS (
    SELECT 1 FROM FraudAlerts fa WHERE fa.transaction_id = t.transaction_id AND fa.rule_id = 2
);

INSERT INTO FraudAlerts (transaction_id, rule_id, status)
SELECT t.transaction_id, 3, 'investigating'
FROM Transactions t
WHERE t.is_fraud = 0 AND t.v17 < -2.5
  AND NOT EXISTS (
    SELECT 1 FROM FraudAlerts fa WHERE fa.transaction_id = t.transaction_id AND fa.rule_id = 3
);

INSERT INTO FraudAlerts (transaction_id, rule_id, status)
SELECT t.transaction_id, 4, 'investigating'
FROM Transactions t
WHERE t.is_fraud = 0 AND t.v12 < -2.0
  AND NOT EXISTS (
    SELECT 1 FROM FraudAlerts fa WHERE fa.transaction_id = t.transaction_id AND fa.rule_id = 4
);

INSERT INTO FraudAlerts (transaction_id, rule_id, status)
SELECT t.transaction_id, 5, 'investigating'
FROM Transactions t
WHERE t.is_fraud = 0 AND t.v10 < -2.0
  AND NOT EXISTS (
    SELECT 1 FROM FraudAlerts fa WHERE fa.transaction_id = t.transaction_id AND fa.rule_id = 5
);

INSERT INTO FraudAlerts (transaction_id, rule_id, status)
SELECT t.transaction_id, 6, 'investigating'
FROM Transactions t
WHERE t.amount > 800
  AND NOT EXISTS (
    SELECT 1 FROM FraudAlerts fa WHERE fa.transaction_id = t.transaction_id AND fa.rule_id = 6
);

-- 4. View Alerts by Severity
SELECT 
    fa.alert_id, t.transaction_id, t.amount, r.rule_name, r.severity, fa.status
FROM FraudAlerts fa
JOIN Transactions t ON fa.transaction_id = t.transaction_id
JOIN FraudRules r ON fa.rule_id = r.rule_id
ORDER BY r.severity DESC;
-- View 1: Recent Confirmed Frauds
CREATE OR REPLACE VIEW RecentConfirmedFrauds AS
SELECT 
    t.transaction_id,
    t.amount,
    t.transaction_date,
    c.first_name,
    c.last_name,
    a.account_number,
    r.rule_name,
    fa.status
FROM FraudAlerts fa
JOIN Transactions t ON fa.transaction_id = t.transaction_id
JOIN Accounts a ON t.account_id = a.account_id
JOIN Customers c ON a.customer_id = c.customer_id
JOIN FraudRules r ON fa.rule_id = r.rule_id
WHERE fa.status = 'confirmed'
ORDER BY t.transaction_date DESC
LIMIT 100;

-- View 2: Top Accounts by Fraud Alerts
CREATE OR REPLACE VIEW TopFraudAccounts AS
SELECT 
    a.account_number,
    COUNT(*) AS fraud_alerts
FROM FraudAlerts fa
JOIN Transactions t ON fa.transaction_id = t.transaction_id
JOIN Accounts a ON t.account_id = a.account_id
GROUP BY a.account_number
ORDER BY fraud_alerts DESC;

-- View 3: High Severity Alerts
CREATE OR REPLACE VIEW HighSeverityAlerts AS
SELECT 
    fa.alert_id,
    t.transaction_id,
    t.amount,
    t.transaction_date,
    r.rule_name,
    r.severity,
    c.first_name,
    c.last_name
FROM FraudAlerts fa
JOIN Transactions t ON fa.transaction_id = t.transaction_id
JOIN FraudRules r ON fa.rule_id = r.rule_id
JOIN Accounts a ON t.account_id = a.account_id
JOIN Customers c ON a.customer_id = c.customer_id
WHERE r.severity >= 4
ORDER BY t.transaction_date DESC;
SELECT * FROM RecentConfirmedFrauds;
SELECT * FROM TopFraudAccounts;
SELECT * FROM HighSeverityAlerts;
SELECT v1, v2, v3, v10, v17, v28, amount, is_fraud
FROM Transactions
ORDER BY transaction_id DESC
LIMIT 5;
ALTER TABLE Transactions ADD INDEX idx_account_id (account_id);
ALTER TABLE Transactions ADD INDEX idx_card_id (card_id);
ALTER TABLE Transactions ADD INDEX idx_transaction_time (transaction_time);
ALTER TABLE Transactions ADD INDEX idx_v14 (v14);
ALTER TABLE Transactions ADD COLUMN ml_prediction TINYINT DEFAULT NULL;
ALTER TABLE Transactions ADD COLUMN ml_confidence FLOAT DEFAULT NULL;

