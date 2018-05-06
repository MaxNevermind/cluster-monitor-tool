#!/usr/bin/env bash

# This is a pattern of a config file for deployment script, see README.md for more details.

# IMPORTANT! Do not just run this file, use "Sourcing a File" and after that run a deployment script itself.
# Usage examples
# Wrong: "./deploy-config.sh"
# Correct: ". ./deploy-config.sh"

# SSH params
export SSH_KEY_PATH="/home/ubuntu/.ssh/id_rsa"
export CLUSTER_USER="ubuntu"

# IPs
export MASTER_IP="10.0.4.47"
export SLAVE_IPS="10.0.4.47;10.0.4.29"