# =====================================
# Credit Scoring Model Inference Script
# =====================================
# This script is designed for model serving environments (e.g., Azure ML, Flask API).
# It exposes an `init()` function to load the model and a `run()` function to score input data.

import joblib
import numpy as np
import json
import os

# =====================================
# INIT: Load Model at Startup
# =====================================

def init():
    """
    Initializes the model by loading it from disk into memory.
    This is typically called once when the server starts.
    """
    global model

    # Use a relative path to access the saved model
    model_path = os.path.join("agents", "credit_scoring", "credit_scoring_model.joblib")

    # Load the trained model into memory
    model = joblib.load(model_path)

# =====================================
# RUN: Perform Inference
# =====================================

def run(raw_data):
    """
    Runs the loaded model on a single set of input features.

    Parameters:
    - raw_data (str): A JSON string containing input feature values.

    Returns:
    - int: Prediction result (e.g., 0 for not defaulted, 1 for defaulted)
    """
    # Parse incoming JSON string into a dictionary
    data = json.loads(raw_data)

    # Extract features in the same order as used during training
    features = [
        data["credit_util_ratio"],
        data["eps_basic"],
        data["eps_diluted"],
        data["avg_monthly_income"],
        data["cash_and_equivalents"],
        data["high_utilization_flag"]
    ]

    # Run model prediction on the input features
    prediction = model.predict([features])

    # Return predicted class label as integer
    return int(prediction[0])
