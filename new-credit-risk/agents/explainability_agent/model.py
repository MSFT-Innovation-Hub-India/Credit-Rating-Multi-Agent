# =====================================
# Train Explainability Model for Credit Default
# =====================================
# This script trains a logistic regression model with numeric and categorical features,
# wrapped in a preprocessing pipeline, and saves the final model for SHAP analysis.

import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report
import joblib

# =====================================
# STEP 1: Load Training Data
# =====================================

# Use a project-relative path instead of a hardcoded absolute path
data_path = os.path.join("agents", "explainability_agent", "credit_data.csv")
df = pd.read_csv(data_path)

# Split into features (X) and target (y)
X = df.drop("Defaulted", axis=1)
y = df["Defaulted"]

# =====================================
# STEP 2: Preprocessing Definition
# =====================================

# Categorical and numerical feature separation
categorical_features = ["Industry_Sector", "Country"]
numerical_features = [col for col in X.columns if col not in categorical_features]

# Define column transformer with scaling and encoding
preprocessor = ColumnTransformer([
    ("num", StandardScaler(), numerical_features),
    ("cat", OneHotEncoder(drop='first', sparse_output=False), categorical_features)
])

# =====================================
# STEP 3: Define Model Pipeline
# =====================================

model_pipeline = Pipeline([
    ("preprocessor", preprocessor),
    ("classifier", LogisticRegression(solver='liblinear', random_state=42))
])

# =====================================
# STEP 4: Split Train/Test
# =====================================

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# =====================================
# STEP 5: Train the Model
# =====================================

model_pipeline.fit(X_train, y_train)

# =====================================
# STEP 6: Evaluate Performance
# =====================================

y_pred = model_pipeline.predict(X_test)
print("📊 Classification Report:\n")
print(classification_report(y_test, y_pred))

# =====================================
# STEP 7: Save Trained Model and Clean Data
# =====================================

# Save model pipeline for SHAP use
model_path = os.path.join("agents", "explainability_agent", "final_pipeline.pkl")
joblib.dump(model_pipeline, model_path)
print(f"✅ Model saved to: {model_path}")

# Save cleaned dataset used for training
clean_data_path = os.path.join("agents", "explainability_agent", "credit_data_clean.csv")
df.to_csv(clean_data_path, index=False)
print(f"✅ Clean training data saved to: {clean_data_path}")
# =====================================