THIS IS FOR CONFIGURING ALL 3 MCP SERVERS AT THE SAME TIME

In order, run: 

install python, curl, and git

1. 
chmod +x setup.sh
./setup.sh 

This installs all dependencies for GCCIS API communication and sets up all MCPs. 

2. 
chmod +x gateway_verify.sh
./gateway_verify.sh

This verifies that the machine is able to connect to the GCCIS API.

3. 
msfrpcd -P yourpassword -p 55553 -n

This manually starts the Metasploit MCP

4. 
python3 hexstrike_server.py

This manually starts the Hexstrike MCP

5. 
python3 verify_mcp.py

This verifies all mcp servers have all their dependencies and are reachable.

6. 
python3 -c "import inspect; from mcp.client.stdio import stdio_client; \ print('errlog' in inspect.signature(stdio_client).parameters)"

This checks to see if errlog is supported. 
If it returns, FALSE, enter:
pip install --upgrade "mcp[cli]"

7. 
python3 run_agent.py

This is where the main logic for the LLM call is, with a 3 hour timeout.
Log files will exist in the root directory with the names: 
- mcp-pymetasploit3_stderr.log
- hexstrike_stderr.log
- pentestgpt_stderr.log