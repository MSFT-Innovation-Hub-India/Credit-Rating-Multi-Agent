# =====================================
# Credit Scoring Model Trainer
# =====================================
# Trains a logistic regression model on financial features to predict default risk.
# Saves both the trained model and the list of feature columns.

import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib
import os

# =====================================
# STEP 1: Load Training Data
# =====================================

# Use a project-relative path instead of a hardcoded local path
data_path = os.path.join("agents", "credit_scoring", "data.csv")

# Load dataset into a pandas DataFrame
df = pd.read_csv(data_path)

# Select features and target column
feature_cols = [
    "credit_util_ratio",
    "eps_basic",
    "eps_diluted",
    "avg_monthly_income",
    "cash_and_equivalents",
    "high_utilization_flag"
]
X = df[feature_cols]
y = df["defaulted"]

# =====================================
# STEP 2: Split Data into Train/Test
# =====================================

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# =====================================
# STEP 3: Train Logistic Regression Model
# =====================================

model = LogisticRegression()
model.fit(X_train, y_train)

# =====================================
# STEP 4: Evaluate Model Performance
# =====================================

y_pred = model.predict(X_test)
print("📊 Classification Report:\n")
print(classification_report(y_test, y_pred))

# =====================================
# STEP 5: Save Trained Model and Feature Order
# =====================================

# Save the trained model using joblib
model_path = os.path.join("agents", "credit_scoring", "credit_scoring_model.joblib")
joblib.dump(model, model_path)
print(f"✅ Model saved to: {model_path}")

# Save the order of feature names for future inference
features_path = os.path.join("agents", "credit_scoring", "features.txt")
with open(features_path, "w") as f:
    f.write(",".join(feature_cols))
print(f"✅ Feature order saved to: {features_path}")
# =====================================
# Utility Function: Convert RAG Summary to Structured JSON