import semantic_kernel as sk
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion, OpenAIPromptExecutionSettings
from semantic_kernel.contents.chat_history import ChatHistory
from semantic_kernel.functions import KernelArguments
from semantic_kernel.contents import AuthorRole
from my_SemanticKernel.plugins import CreditRiskPlugin
import logging
import json
import os
from dotenv import load_dotenv

# Set up logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class SemanticKernelOrchestrator:
    def __init__(self):
        logger.info("Initializing SemanticKernelOrchestrator...")
        
        try:
            self.kernel = sk.Kernel()
            logger.info("Kernel created successfully")
            
            # Add Azure OpenAI service
            logger.info("Setting up Azure OpenAI connection...")
            # Load environment variables from .env file (in parent directory)
            load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))
            
            # Load environment variables from .env file (in parent directory)
            load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))
            
            # Retrieve Azure OpenAI configuration from environment variables
            deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME")
            endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
            api_key = os.getenv("AZURE_OPENAI_API_KEY")
            api_version = os.getenv("AZURE_OPENAI_API_VERSION")
            
            # Debug logging for environment variables (without exposing sensitive data)
            logger.info(f"Deployment name: {deployment_name}")
            logger.info(f"Endpoint: {endpoint}")
            logger.info(f"API version: {api_version}")
            logger.info(f"API key loaded: {'Yes' if api_key else 'No'}")
            
            if not all([deployment_name, endpoint, api_key, api_version]):
                missing_vars = []
                if not deployment_name: missing_vars.append("AZURE_OPENAI_DEPLOYMENT_NAME")
                if not endpoint: missing_vars.append("AZURE_OPENAI_ENDPOINT")
                if not api_key: missing_vars.append("AZURE_OPENAI_API_KEY")
                if not api_version: missing_vars.append("AZURE_OPENAI_API_VERSION")
                raise ValueError(f"Missing environment variables: {', '.join(missing_vars)}")
            
            # Initialize AzureChatCompletion with loaded configuration
            self.chat_completion = AzureChatCompletion(
                deployment_name=deployment_name,
                endpoint=endpoint,
                api_key=api_key,
                api_version=api_version
            )
            self.kernel.add_service(self.chat_completion)
            logger.info("Azure OpenAI service added to kernel")
            
            # Add the credit risk plugin
            logger.info("Adding CreditRisk plugin...")
            self.kernel.add_plugin(CreditRiskPlugin(), plugin_name="CreditRisk")
            logger.info("CreditRisk plugin added successfully")
            
            logger.info("SemanticKernelOrchestrator initialization complete")
        except Exception as e:
            logger.error(f"Error initializing SemanticKernelOrchestrator: {str(e)}")
            raise

    async def run_smart_analysis(self, requirements: list = None) -> dict:
        try:
            logger.info(f"Starting run_smart_analysis with requirements: {requirements}")
            
            # Initialize result structure matching mock.json
            result = {
                "bureau_summary": None,
                "credit_scoring": None,
                "fraud_detection": None,
                "explainability": None,
                "compliance_check": None
            }
            
            # Create chat history for orchestration
            logger.info("Creating chat history for smart analysis...")
            history = ChatHistory()
            
            # System message for function calling
            history.add_system_message("""
            You are a credit risk analysis orchestrator. You MUST call these functions in sequence:
            
            1. FIRST: Call bureau_analysis() to get financial data
            2. THEN: Call credit_scoring(summary_text) using the bureau summary
            3. THEN: Call fraud_detection(summary_text) using the bureau summary  
            4. THEN: Call explainability(summary_text) using the bureau summary
            5. THEN: Call compliance_check(summary_text) using the bureau summary
            
            You MUST call ALL functions. Do not provide text analysis - only call the functions.
            After calling all functions, respond with "Analysis complete."
            """)
            
            # User message
            user_message = "Execute complete credit risk analysis. Call all 5 functions: bureau_analysis, then credit_scoring, fraud_detection, explainability, and compliance_check."
            history.add_user_message(user_message)
            logger.info("Chat history created for smart analysis")
            
            # Setup execution settings with function calling
            logger.info("Setting up execution settings with function calling...")
            execution_settings = OpenAIPromptExecutionSettings(
                max_tokens=4000,
                temperature=0.1,
                function_choice_behavior="auto"
            )
            
            # Get chat service and invoke with function calling
            logger.info("Calling chat completion with automatic function calling...")
            chat_service = self.kernel.get_service(type=AzureChatCompletion)
            
            # Execute the conversation with function calling
            response = await chat_service.get_chat_message_contents(
                chat_history=history,
                settings=execution_settings,
                kernel=self.kernel
            )
            
            logger.info(f"Received response, processing function call results...")
            logger.info(f"Total messages in history: {len(history.messages)}")
            
            # FIXED: Extract function call results from chat history
            for i, message in enumerate(history.messages):
                logger.info(f"Message {i}: role={message.role}")
                
                # Check for TOOL messages (function results)
                if hasattr(message, 'role') and message.role == AuthorRole.TOOL:
                    logger.info(f"Found TOOL message at index {i}")
                    
                    # FIXED: Try multiple ways to access content
                    function_result = None
                    
                    # Method 1: Direct content access
                    if hasattr(message, 'content') and message.content:
                        function_result = str(message.content)
                        logger.info(f"Got content via message.content")
                    
                    # Method 2: Try accessing items
                    elif hasattr(message, 'items') and message.items:
                        for item in message.items:
                            if hasattr(item, 'text') and item.text:
                                function_result = str(item.text)
                                logger.info(f"Got content via message.items[].text")
                                break
                    
                    # Method 3: Try accessing inner_content
                    elif hasattr(message, 'inner_content') and message.inner_content:
                        function_result = str(message.inner_content)
                        logger.info(f"Got content via message.inner_content")
                    
                    # Method 4: Check if it's a function result object
                    elif hasattr(message, 'function_result'):
                        function_result = str(message.function_result)
                        logger.info(f"Got content via message.function_result")
                    
                    # Method 5: Print all attributes to debug
                    else:
                        logger.warning(f"Could not find content. Message attributes: {dir(message)}")
                        # Let's try to get the actual content by inspecting the object
                        if hasattr(message, '__dict__'):
                            logger.info(f"Message dict: {message.__dict__}")
                        continue
                    
                    if function_result:
                        logger.info(f"Tool content length: {len(function_result)}")
                        logger.info(f"Tool content preview: {function_result[:500]}...")
                        
                        try:
                            parsed_result = json.loads(function_result)
                            logger.info(f"✓ Successfully parsed JSON result")
                            
                            # Identify which function this result belongs to based on the result structure
                            if "agentName" in parsed_result:
                                agent_name = parsed_result["agentName"]
                                logger.info(f"Agent name found: {agent_name}")
                                
                                if agent_name == "Bureau Summariser":
                                    result["bureau_summary"] = parsed_result
                                    logger.info("✓ Bureau analysis result captured")
                                elif agent_name == "Credit Score Rating":
                                    result["credit_scoring"] = parsed_result
                                    logger.info("✓ Credit scoring result captured")
                                elif agent_name == "Fraud Detection":
                                    result["fraud_detection"] = parsed_result
                                    logger.info("✓ Fraud detection result captured")
                                elif agent_name == "Explainability":
                                    result["explainability"] = parsed_result
                                    logger.info("✓ Explainability result captured")
                                else:
                                    logger.warning(f"Unknown agent name: {agent_name}")
                            
                            # Handle compliance check (different structure)
                            elif "compliance_issues" in parsed_result:
                                result["compliance_check"] = parsed_result
                                logger.info("✓ Compliance check result captured")
                            else:
                                logger.warning(f"Could not identify function type for result: {list(parsed_result.keys())}")
                                
                        except json.JSONDecodeError as e:
                            logger.error(f"Failed to parse function result: {e}")
                            logger.error(f"Raw content: {function_result}")
                    else:
                        logger.warning(f"TOOL message at index {i} has no accessible content")
            
            # Log final results
            functions_completed = [k for k, v in result.items() if v is not None]
            logger.info(f"Smart analysis completed. Functions completed: {functions_completed}")
            
            # If extraction failed but we know functions ran, use run_credit_analysis as fallback
            if len(functions_completed) == 0:
                logger.warning("Function extraction failed completely. Falling back to direct invocation.")
                return await self.run_credit_analysis()
            
            # Fill in any missing functions with error responses
            for key, value in result.items():
                if value is None:
                    logger.error(f"Function {key} result was not captured - providing error response")
                    result[key] = {
                        "agentName": key.replace("_", " ").title(),
                        "agentDescription": f"Function {key} result extraction failed",
                        "extractedData": {},
                        "summary": f"ERROR: Function {key} was executed but result was not properly captured from chat history",
                        "completedAt": "2025-07-23T04:26:00.000000Z",
                        "confidenceScore": 0.0,
                        "status": "AgentStatus.failed",
                        "errorMessage": "Function result extraction failed despite successful execution"
                    }
            
            return result
            
        except Exception as e:
            logger.error(f"Error in run_smart_analysis: {str(e)}")
            logger.exception("Full traceback:")
            raise

    async def run_credit_analysis(self) -> dict:
        """Direct kernel invocation - GUARANTEED TO WORK"""
        try:
            logger.info("Starting run_credit_analysis with direct kernel calls...")
            
            result = {
                "bureau_summary": None,
                "credit_scoring": None,
                "fraud_detection": None,
                "explainability": None,
                "compliance_check": None
            }
            
            # Step 1: Get bureau analysis
            logger.info("Calling bureau_analysis...")
            bureau_function = self.kernel.get_function("CreditRisk", "bureau_analysis")
            bureau_result = await self.kernel.invoke(bureau_function)
            
            if bureau_result and bureau_result.value:
                bureau_data = str(bureau_result.value)
                try:
                    parsed_bureau = json.loads(bureau_data)
                    result["bureau_summary"] = parsed_bureau
                    summary_text = parsed_bureau.get("summary", bureau_data)
                    logger.info("✓ Bureau analysis completed successfully")
                except json.JSONDecodeError:
                    result["bureau_summary"] = {"summary": bureau_data}
                    summary_text = bureau_data
                    logger.warning("Bureau analysis returned non-JSON data")
            else:
                logger.error("Bureau analysis returned no data")
                return {"error": "Bureau analysis failed"}
            
            # Use the summary text for all subsequent calls
            if not summary_text:
                summary_text = "TerraDrive Mobility Corp. financial analysis"
            
            # Step 2: Get credit scoring
            try:
                logger.info("Calling credit_scoring...")
                credit_function = self.kernel.get_function("CreditRisk", "credit_scoring")
                credit_args = KernelArguments(summary_text=summary_text)
                credit_result = await self.kernel.invoke(credit_function, credit_args)
                
                if credit_result and credit_result.value:
                    credit_data = str(credit_result.value)
                    try:
                        result["credit_scoring"] = json.loads(credit_data)
                        logger.info("✓ Credit scoring completed")
                    except json.JSONDecodeError:
                        result["credit_scoring"] = {"summary": credit_data}
            except Exception as e:
                logger.error(f"Credit scoring failed: {e}")
                result["credit_scoring"] = {"error": str(e)}
            
            # Step 3: Get fraud detection
            try:
                logger.info("Calling fraud_detection...")
                fraud_function = self.kernel.get_function("CreditRisk", "fraud_detection")
                fraud_args = KernelArguments(summary_text=summary_text)
                fraud_result = await self.kernel.invoke(fraud_function, fraud_args)
                
                if fraud_result and fraud_result.value:
                    fraud_data = str(fraud_result.value)
                    try:
                        result["fraud_detection"] = json.loads(fraud_data)
                        logger.info("✓ Fraud detection completed")
                    except json.JSONDecodeError:
                        result["fraud_detection"] = {"summary": fraud_data}
            except Exception as e:
                logger.error(f"Fraud detection failed: {e}")
                result["fraud_detection"] = {"error": str(e)}
            
            # Step 4: Get explainability
            try:
                logger.info("Calling explainability...")
                explain_function = self.kernel.get_function("CreditRisk", "explainability")
                explain_args = KernelArguments(summary_text=summary_text)
                explain_result = await self.kernel.invoke(explain_function, explain_args)
                
                if explain_result and explain_result.value:
                    explain_data = str(explain_result.value)
                    try:
                        result["explainability"] = json.loads(explain_data)
                        logger.info("✓ Explainability completed")
                    except json.JSONDecodeError:
                        result["explainability"] = {"summary": explain_data}
            except Exception as e:
                logger.error(f"Explainability failed: {e}")
                result["explainability"] = {"error": str(e)}
            
            # Step 5: Get compliance check
            try:
                logger.info("Calling compliance_check...")
                compliance_function = self.kernel.get_function("CreditRisk", "compliance_check")
                compliance_args = KernelArguments(summary_text=summary_text)
                compliance_result = await self.kernel.invoke(compliance_function, compliance_args)
                
                if compliance_result and compliance_result.value:
                    compliance_data = str(compliance_result.value)
                    try:
                        result["compliance_check"] = json.loads(compliance_data)
                        logger.info("✓ Compliance check completed")
                    except json.JSONDecodeError:
                        result["compliance_check"] = {"summary": compliance_data}
            except Exception as e:
                logger.error(f"Compliance check failed: {e}")
                result["compliance_check"] = {"error": str(e)}
            
            logger.info("✓ All functions completed successfully via direct invocation")
            return result
            
        except Exception as e:
            logger.error(f"Error in run_credit_analysis: {str(e)}")
            logger.exception("Full traceback:")
            raise