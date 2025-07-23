from semantic_kernel.functions import kernel_function
from core.bureau_pipeline import bureau_agent_pipeline
from core.credit_pipeline import credit_scoring_pipeline
from core.fraud_pipeline import fraud_detection_pipeline
from core.explainability_pipeline import explainability_agent_pipeline
from core.compliance_pipeline import compliance_agent_pipeline
import logging
import json

# Set up logging
logger = logging.getLogger(__name__)

class CreditRiskPlugin:
    @kernel_function(
        description="Analyzes and summarizes business documents and financial statements",
        name="bureau_analysis"
    )
    def bureau_analysis(self) -> str:
        """Runs bureau agent pipeline and returns JSON result."""
        logger.info("Starting bureau_analysis function...")
        try:
            logger.info("Calling bureau_agent_pipeline...")
            result = bureau_agent_pipeline()
            logger.info(f"Bureau pipeline result status: {result.get('status')}")
            
            if result.get("status") != "AgentStatus.complete":
                error_msg = f"Bureau agent failed: {result.get('errorMessage')}"
                logger.error(error_msg)
                return json.dumps({"error": error_msg})
            
            logger.info(f"Bureau analysis completed successfully")
            return json.dumps(result)
            
        except Exception as e:
            logger.error(f"Error in bureau_analysis: {str(e)}")
            return json.dumps({"error": str(e)})

    @kernel_function(
        description="Calculates credit risk and assigns AAA–DDD rating",
        name="credit_scoring"
    )
    def credit_scoring(self, summary_text: str) -> str:
        """Performs credit scoring analysis and returns JSON result."""
        logger.info(f"Starting credit_scoring function...")
        try:
            # Extract summary from JSON if needed
            if summary_text.startswith('{'):
                try:
                    data = json.loads(summary_text)
                    actual_summary = data.get('summary', summary_text)
                except:
                    actual_summary = summary_text
            else:
                actual_summary = summary_text
                
            logger.info("Calling credit_scoring_pipeline...")
            result = credit_scoring_pipeline(actual_summary)
            logger.info("Credit scoring pipeline completed")
            
            return json.dumps(result)
            
        except Exception as e:
            logger.error(f"Error in credit_scoring: {str(e)}")
            return json.dumps({"error": str(e)})

    @kernel_function(
        description="Identifies potential fraud indicators and risk factors",
        name="fraud_detection"
    )
    def fraud_detection(self, summary_text: str) -> str:
        """Performs fraud detection analysis and returns JSON result."""
        logger.info(f"Starting fraud_detection function...")
        try:
            # Extract summary from JSON if needed
            if summary_text.startswith('{'):
                try:
                    data = json.loads(summary_text)
                    actual_summary = data.get('summary', summary_text)
                except:
                    actual_summary = summary_text
            else:
                actual_summary = summary_text
                
            logger.info("Calling fraud_detection_pipeline...")
            result = fraud_detection_pipeline(actual_summary)
            logger.info("Fraud detection pipeline completed")
            
            return json.dumps(result)
            
        except Exception as e:
            logger.error(f"Error in fraud_detection: {str(e)}")
            return json.dumps({"error": str(e)})

    @kernel_function(
        description="Provides detailed explanation of analysis decisions and factors",
        name="explainability"
    )
    def explainability(self, summary_text: str) -> str:
        """Provides explainability analysis and returns JSON result."""
        logger.info(f"Starting explainability function...")
        try:
            # Extract summary from JSON if needed
            if summary_text.startswith('{'):
                try:
                    data = json.loads(summary_text)
                    actual_summary = data.get('summary', summary_text)
                except:
                    actual_summary = summary_text
            else:
                actual_summary = summary_text
                
            logger.info("Calling explainability_agent_pipeline...")
            result = explainability_agent_pipeline(actual_summary)
            logger.info("Explainability pipeline completed")
            
            return json.dumps(result)
            
        except Exception as e:
            logger.error(f"Error in explainability: {str(e)}")
            return json.dumps({"error": str(e)})

    @kernel_function(
        description="Checks legal compliance and regulatory requirements",
        name="compliance_check"
    )
    def compliance_check(self, summary_text: str) -> str:
        """Performs compliance checking and returns JSON result."""
        logger.info(f"Starting compliance_check function...")
        try:
            # Extract summary from JSON if needed
            if summary_text.startswith('{'):
                try:
                    data = json.loads(summary_text)
                    actual_summary = data.get('summary', summary_text)
                except:
                    actual_summary = summary_text
            else:
                actual_summary = summary_text
                
            logger.info("Calling compliance_agent_pipeline...")
            result = compliance_agent_pipeline(actual_summary)
            logger.info("Compliance pipeline completed")
            
            # Ensure result is in proper format
            if not isinstance(result, dict):
                result = {"summary": str(result), "status": "completed"}
            
            return json.dumps(result)
            
        except Exception as e:
            logger.error(f"Error in compliance_check: {str(e)}")
            return json.dumps({"error": str(e)})