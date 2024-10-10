#!/bin/bash

# Step 1: Install Docker
echo "Installing Docker..."
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker

# Step 2: Clone the repository
echo "Cloning the repository..."
git clone git@github.com:sixgpt/miner.git
cd miner || exit

# Step 3: Prompt user to input the private key
read -p "Please enter your VANA private key: " VANA_PRIVATE_KEY

# Set environment variables
echo "Setting environment variables..."
export VANA_PRIVATE_KEY=$VANA_PRIVATE_KEY
export VANA_NETWORK=satori

# Step 4: Run the miner
echo "Starting the miner..."
docker compose up
