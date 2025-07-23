# =====================================
# RAG Summary Parser: TXT to JSON
# =====================================
# This script reads a financial RAG summary (as plain text),
# extracts key-value pairs from structured lines,
# and compiles the rest into a free-form "basic_analysis" field.

import re
import os  # For file path operations
import json

# =====================================
# Main Extraction Function
# =====================================
3
def rag_summary_to_json(text: str) -> dict:
    """
    Converts RAG-generated plain-text summaries into structured JSON.
    
    Parameters:
    - text (str): The full text of the RAG summary.

    Returns:
    - dict: Structured data with fields like Revenue, Net Income, etc., and a 'basic_analysis' block.
    """
    # Fields to extract if they appear as "Field: Value" in the text
    fields = [
        "Revenue", "Net Income", "Total Assets", "Total Liabilities", "Equity",
        "Country", "Industry"
    ]
    
    data = {}               # Output dictionary
    structured_lines = []   # Lines with matched fields
    remaining_lines = []    # All other lines, to be preserved as commentary

    # Clean and split input text into non-empty lines
    lines = [line.strip() for line in text.strip().splitlines() if line.strip()]

    # Process each line individually
    for line in lines:
        matched = False  # Flag to check if current line matches a field

        # Try matching the line with any of the expected fields
        for field in fields:
            if line.lower().startswith(field.lower() + ":"):
                # Extract the value after the colon
                value = line.split(":", 1)[1].strip()

                # Clean: Remove anything in parentheses (e.g., units or notes)
                cleaned_value = value.split("(")[0].strip()

                # Normalize key format (e.g., "Net Income" → "Net_Income")
                data[field.replace(" ", "_")] = cleaned_value

                structured_lines.append(line)
                matched = True
                break  # No need to check other fields for this line

        if not matched:
            # If the line didn't match any expected field, keep it as raw analysis
            remaining_lines.append(line)

    # Add leftover content as a general narrative summary
    data["basic_analysis"] = " ".join(remaining_lines)

    return data

# =====================================
# File I/O: Example Usage
# =====================================

# Path to raw summary file (edit path as needed)
rag_summary_path = os.path.join("output_data", "rag_summary.txt")

# Read input text from file
with open(rag_summary_path, "r", encoding="utf-8") as f:
    text = f.read()

# Convert text to structured JSON
summary_json = rag_summary_to_json(text)

# Define path to save output
output_path = rag_summary_path.replace(".txt", ".json")

# Write structured data to .json file
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(summary_json, f, indent=4)

print("✅ Converted RAG summary to JSON.")
