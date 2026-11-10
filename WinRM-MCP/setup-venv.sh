#!/bin/sh
python3 -m venv venv
venv/bin/pip install --upgrade pip
venv/bin/pip install 'mcp<2' pywinrm
