# ===============================================
# Train Fraud Detection Model (Random Forest + Preprocessing)
# ===============================================
# This script trains a fraud detection classifier using business financial features.
# It includes preprocessing for numerical and categorical data, model evaluation, and saving to disk.

import os
import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report

# ===============================================
# STEP 1: Load CSV Dataset
# ===============================================
csv_path = os.path.join("agents", "fraud_detection", "fraud_detection_dataset.csv")
df = pd.read_csv(csv_path)

# ===============================================
# STEP 2: Clean Columns (Remove ID if exists)
# ===============================================
if 'RecordID' in df.columns:
    df = df.drop(columns=['RecordID'])

# ===============================================
# STEP 3: Split Features & Target
# ===============================================
X = df.drop("Is_Fraud", axis=1)  # Features
y = df["Is_Fraud"]               # Target label

# ===============================================
# STEP 4: Define Preprocessing Pipelines
# ===============================================
numeric_features = ["Revenue", "Net_Income", "Total_Assets", "Total_Liabilities", "Equity"]
categorical_features = ["Industry_Sector", "Country"]

# Transformer to scale numerics and encode categoricals
preprocessor = ColumnTransformer(transformers=[
    ("num", StandardScaler(), numeric_features),
    ("cat", OneHotEncoder(handle_unknown='ignore'), categorical_features)
])

# ===============================================
# STEP 5: Build Full Pipeline with Classifier
# ===============================================
pipeline = Pipeline(steps=[
    ("preprocessor", preprocessor),
    ("classifier", RandomForestClassifier(n_estimators=100, random_state=42))
])

# ===============================================
# STEP 6: Train/Test Split
# ===============================================
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# ===============================================
# STEP 7: Train the Model
# ===============================================
pipeline.fit(X_train, y_train)

# ===============================================
# STEP 8: Evaluate on Test Set
# ===============================================
y_pred = pipeline.predict(X_test)
print("\n📊 Classification Report:")
print(classification_report(y_test, y_pred))

# ===============================================
# STEP 9: Save the Trained Model to Disk
# ===============================================
model_path = os.path.join("agents", "fraud_detection", "fraud_model.joblib")
joblib.dump(pipeline, model_path)
print(f"\n✅ Model saved at: {model_path}")
