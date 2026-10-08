In order, run: 

sudo apt update

sudo apt install curl -y
sudo apt install git -y
sudo apt install python3-pip -y

git clone https://github.com/Post-Exploitation-LLM-Behavior/AI.git
cd AI/Hexstrike-AI

Create the .env file. 

chmod +x gateway_verify.sh
./gateway_verify.sh

chmod +x hexstrike-setup.sh
./hexstrike-setup.sh

Paste the correct mcp configuration in mcp_config.json

cd hexstrike-ai
./venv/bin/python3 hexstrike_server.py

python3 verify_mcp.py

python3 test_hexstrike.py

python3 -c "import inspect; from mcp.client.stdio import stdio_client; \ print('errlog' in inspect.signature(stdio_client).parameters)"

This checks to see if errlog is supported. 
If it returns, FALSE, enter:
pip install --upgrade "mcp[cli]"

python3 run_agent.py

This is where the main logic for the LLM call is, with a 3 hour timeout.
Log files will exist in the root directory with the name: 
- hexstrike_stderr.log