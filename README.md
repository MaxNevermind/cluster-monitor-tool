## About the project
A simple Dockerized cluster monitor tool with a deployment script. It monitors both hosts and Dokcer containers on them.
This project is a simplified version of `https://github.com/stefanprodan/dockprom` with a deployment script added
___

## Overview of the solution

#### Components
- Docker engine
- Docker composer - describe multiple containers and run them using just one command
- cAdvisor - expose container's metrics
- Prometheus node exporter - expose cluster's machines metrics
- Prometheus - collect metrics from specified sources, store them, and provide query API
- Grafana - visualize metrics

![Project components](doc/ProjectComponents.png?raw=true "Project components")

*note that AlertManager is not used in this project, though we can plug it in if needed.

#### How it works
Node exporter containers(one per each slave and master) expose host machine OS metrics, container can access it 
because of mounted volumes on a container, you can find these lines in `docker-compose.exporters.yml`: 
```
container_name: nodeexporter
volumes:
  - /proc:/host/proc:ro
  - /sys:/host/sys:ro
  - /:/rootfs:ro
```
- cAdvisor container exposes containers metrics.
- Prometheus container gathers exposed metrics and store it(by default for 200 hours).
- Grafana container uses Prometheus as a data source for it's graphs.
- Grfana and Prometheus are started in deploy.sh using docker-compose.exporters.yml, cAdvisor and Node exporter are started in deploy.sh using docker-compose.yml.
___



## Installation

#### Prerequisites
- Deployment script is written for Ubuntu OS, so you have o use it
- You need password-less SSH login to each of the machines in a cluster from a deployment machine.

#### Steps
- Checkout a git repository to a local directory https://bitbucket.org/propzmedia/cluster-performance-monitor
- Change a directory to a parent dir of the project 
- Set deployment config env variables. You can find an example of how to properly set them in a file(`deploy-config.sh`).
- Run a deployment script(`deploy.sh`). Note, this script is supposed to run from the parent directory of this project 
to be able to resolve relative paths. 
####  After installation checks
- You should be able to connect to a web service on a port 9090 `http://master:9090/graph` and run a query "up", you should see something like this:
![After installation checks 1](doc/AfterInstallChecks_1.png?raw=true "After installation checks 1")

- All values should be "1", it means all metrics exposers are up and ready. 
![After installation checks 2](doc/AfterInstallChecks_2.png?raw=true "After installation checks 2")
___

    
    
## Endpoints
#### Master
- grafana `http://MASTER_IP:3000/` This is the main UI endpoint with metrics
- prometheus `http://MASTER_IP:9090/`
- cadvisor `http://MASTER_IP:8090/`
- nodeexporter `http://MASTER_IP:9100/`

#### Slaves
- cadvisor `http://SLAVE_IP:8090/`
- nodeexporter `http://SLAVE_IP:9100/`   