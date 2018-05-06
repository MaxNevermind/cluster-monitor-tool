#!/usr/bin/env bash

# This is a deployment script, see README.md for more details.
#
# Usage: deploy.sh (start|stop|restart|install_soft)
#
# IMPORTANT! Note, this script is supposed to run from the parent directory of this project to be able to resolve relative paths.
#
# Details:
# install_soft - installs Docker engine & Docker compose on machines
# /tmp/cluster-performance-monitor-deployment is used as working directory for storing project files on cluster machines.

set -e

USAGE="Usage: deploy.sh (start|stop|restart|install_soft)

    IMPORTANT! Note, this script is supposed to run from the parent directory of this project to be able to resolve relative paths.

    Details:
    install_soft - installs Docker engine & Docker compose on machines
    /tmp/cluster-performance-monitor-deployment is used as working directory for storing project files on cluster machines."

if (( $# < 1 )); then
    echo "$USAGE"
    exit 1
fi

echo "Checking existence of all needed configuration environment variables"
: ${SSH_KEY_PATH?"Need to set SSH_KEY_PATH"}
: ${CLUSTER_USER?"Need to set CLUSTER_USER"}
: ${MASTER_IP?"Need to set MASTER_IP"}
: ${SLAVE_IPS?"Need to set SLAVE_IPS"}

# SSH params
sshKeyPath=$SSH_KEY_PATH
clusterUser=$CLUSTER_USER

# IPs
masterIp=$MASTER_IP
slaveIps=(${SLAVE_IPS//;/ })

workDir=/tmp/cluster-performance-monitor-deployment


# A function forms replacement strings nodeExporterIps, cAdvisorIps for prometheus.yml:
# nodeExporterIps - "['MASTER_IP:9100', 'SLAVE_1_IP:9100', ...]"
# cAdvisorIps - "['MASTER_IP:8090', 'SLAVE_1_IP:8090', ...]"
function formIpReplaceStrings {
    nodeExporterIps="['$MASTER_IP:9100'"
    cAdvisorIps="['$MASTER_IP:8090'"
    for slaveIp in ${slaveIps[@]}
    do
        nodeExporterIps="$nodeExporterIps,'$slaveIp:9100'"
        cAdvisorIps="$cAdvisorIps,'$slaveIp:8090'"
    done
    nodeExporterIps="$nodeExporterIps]"
    cAdvisorIps="$cAdvisorIps]"
}
formIpReplaceStrings

# Copies this project files to all nodes so the scripts can be run on remote machines
function copyProjectFiles {
    echo "Started copying project's files to remote hosts"
    copyProjectFilesToRemoteMachine $masterIp
    for slaveIp in ${slaveIps[@]}
    do
        copyProjectFilesToRemoteMachine $slaveIp
    done
    echo "Finished copying project's files to remote hosts"
}
function copyProjectFilesToRemoteMachine {
    local remoteIp=$1
    echo "Copying project's files to remote host $remoteIp"
#       Refresh this project's files on a remote cluster's host
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$remoteIp \
        sudo rm -rf $workDir
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$remoteIp \
        mkdir -p $workDir
    scp -i $sshKeyPath -rp [!.]* $clusterUser@$remoteIp:$workDir
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$remoteIp \
        sudo chmod 755 -R $workDir
#       Replace correct IPs
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$remoteIp \
        "sudo sed -i -e \"s/NODE_EXPORTER_IPS_REPLACE_STRING/$nodeExporterIps/g\" $workDir/prometheus/prometheus.yml"
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$remoteIp \
        "sudo sed -i -e \"s/CADVISOR_IPS_REPLACE_STRING/$cAdvisorIps/g\" $workDir/prometheus/prometheus.yml"
}

function installSoftware {
    for slaveIp in ${slaveIps[@]}
    do
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$slaveIp << EOF

#    Install Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce

#    Install Docker compose
    sudo curl -L https://github.com/docker/compose/releases/download/1.20.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
EOF
    done
}

function startupContainers {
    # Start up master
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$masterIp \
        sudo /usr/local/bin/docker-compose --file $workDir/docker-compose.yml up -d
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$masterIp \
        sudo /usr/local/bin/docker-compose --file $workDir/docker-compose.exporters.yml up -d

    # Start up slaves
    for slaveIp in ${slaveIps[@]}
    do
        ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$slaveIp \
            sudo /usr/local/bin/docker-compose --file $workDir/docker-compose.exporters.yml up -d
    done
}

function shutdownContainers {
    # Shutdown master
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$masterIp \
        sudo /usr/local/bin/docker-compose --file $workDir/docker-compose.yml down
    ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$masterIp \
        sudo /usr/local/bin/docker-compose --file $workDir/docker-compose.exporters.yml down

    # Shutdown slaves
    for slaveIp in ${slaveIps[@]}
    do
        ssh -o "StrictHostKeyChecking no" -i $sshKeyPath $clusterUser@$slaveIp \
            sudo /usr/local/bin/docker-compose --file $workDir/docker-compose.exporters.yml down
    done
}




case "$1" in
"restart")
    copyProjectFiles $@
    shutdownContainers $@
    startupContainers $@
    ;;
"install_soft")
    installSoftware $@
    ;;
"start")
    copyProjectFiles $@
    startupContainers $@
    ;;
"stop")
    copyProjectFiles $@
    shutdownContainers $@
    ;;
*)
    echo "$USAGE"
    exit 1
    ;;
esac