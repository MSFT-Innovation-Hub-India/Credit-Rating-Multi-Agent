# =====================================
# Train Random Forest Pipeline with Preprocessing
# =====================================
# This script trains a RandomForest classifier for credit default prediction,
# using both numeric and categorical features, and saves the final pipeline for SHAP analysis.

import os
import pandas as pd
import joblib
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.ensemble import RandomForestClassifier

# =====================================
# STEP 1: Load Dataset
# =====================================

# Use a relative path inside the project structure
data_path = os.path.join("agents", "explainability_agent", "credit_data.csv")
data = pd.read_csv(data_path)

# =====================================
# STEP 2: Define Features and Target
# =====================================

X = data.drop("Defaulted", axis=1)
y = data["Defaulted"]

# Separate numerical and categorical features
num_features = ["Revenue", "Net_Income", "Total_Assets", "Total_Liabilities", "Equity"]
cat_features = ["Industry_Sector", "Country"]

# =====================================
# STEP 3: Define Preprocessor and Pipeline
# =====================================

preprocessor = ColumnTransformer(transformers=[
    ("num", StandardScaler(), num_features),
    ("cat", OneHotEncoder(handle_unknown='ignore'), cat_features)
])

pipeline = Pipeline(steps=[
    ("columntransformer", preprocessor),
    ("randomforestclassifier", RandomForestClassifier(random_state=42))
])

# =====================================
# STEP 4: Split Dataset and Train
# =====================================

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

pipeline.fit(X_train, y_train)

# =====================================
# STEP 5: Evaluate with Cross-Validation
# =====================================

cv_accuracy = cross_val_score(pipeline, X, y, cv=5).mean()
print(f"📊 CV Accuracy: {cv_accuracy:.4f}")

# =====================================
# STEP 6: Save Final Pipeline
# =====================================

model_path = os.path.join("agents", "explainability_agent", "final_pipeline.pkl")
joblib.dump(pipeline, model_path)
print(f"✅ Final pipeline saved to: {model_path}")
