# Credit-Rating-Multi-Agent

There are three directories in this repo.

**Data:** Contains the synthetic financial files on which we tested the project, as well as model details and prompts for our AI Foundry agents. 

**x3_gui** is the client side code. (has its own detailed Readme for configuration and running). 

**new-credit-risk** contains the code for the agents. Minimal change has been done to the existing agent pipeline. The additions include using SemanticKernel for agent orchestration.
 - Uses Azure OpenAI Service (GPT-4o-mini) as an orchestration brain for the Semantic Kernel
 - The existing agent pipeline functions have been converted into Kernel Functions so the LLM can call them as tools
 - The LLM orchestrates the calling of tools and returns the results through its chat
 - Chat is parsed for JSON schema compatibility with the frontend
 - New dedicated Endpoints in main API for sk-orchestration (backwards compatibility with the old orchestration system)
- Notes on Limitations: Creating the document indexing in AI Search for the agents to query is still a manual process 