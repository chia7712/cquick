# cquick
a tool to start kafka|hbase standalone service by docker container 

## Getting Started
All related projects and configs have been stored in the docker containers. All you need to do is to run the following command.

##### for kafka
```
$ docker run -e "branch=trunk" chia7712/kafka:quickstart quickstart.sh
```
The **quickstart.sh** will execute the following ops.
1. download the **kafka** source code from https://github.com/apache/kafka
1. checkout the source code to **trunk** branch
1. build the source code and then untar the assembly
1. deploy **1 zookeeper** instance
1. generate the kafka broker configs and deploy **2 kafka brokers**
 
##### for hbase
```
$ docker run -e "branch=master" chia7712/hbase:quickstart quickstart.sh
```
The **quickstart.sh** will execute the following ops.
1. download the **hbase** source code from https://github.com/apache/hbase
1. checkout the source code to **master** branch
1. build the source code and then untar the assembly
1. deploy **1 zookeeper** instance
1. deploy **1 namenode** instance and **1 datanode** instance
1. deploy **1 master** instance
1. generate the regionserver configs and deploy **2 regionserver instances**
 
### Prerequisites

* docker 1.13.1+ with overlay2 storage driver

### Installing

##### for kafka
```
$ docker pull chia7712/kafka:quickstart
```
##### for hbase
```
$ docker pull chia7712/hbase:quickstart
```
## Advanced Usage
There are some options configurable to user.

### how to change the code
You can run the service based on the git revision, release src or release binary.
##### example 1: run the hbase service based on branch-1
```
$ docker run -e "branch=branch-1" chia7712/hbase:quickstart quickstart.sh
```
##### example 2: run the hbase service based on hbase-1.4.3 src
```
$ docker run -e "branch=https://www.apache.org/dist/hbase/1.4.3/hbase-1.4.3-src.tar.gz" chia7712/hbase:quickstart quickstart.sh
```
##### example 3: run the hbase service based on hbase-1.4.3 binary
```
$ docker run -e "branch=https://www.apache.org/dist/hbase/1.4.3/hbase-1.4.3-bin.tar.gz" chia7712/hbase:quickstart quickstart.sh
```

### how to apply the patch to the code
You can define the patch applying to the code before building and running
##### example 1: run the hbase service based on master and patch
```
$ docker run -e "branch=master" -v mypatch:/testpatch/patch chia7712/hbase:quickstart quickstart.sh
```
The quickstart.sh will check the exist of /testpatch/patch, and then apply it to the source code.

**NOTE:** You can only apply the patch to the code under git control.

### how to increase the running node
You can define the number of running regionserver|broker nodes. The min is 1 and max is 5.
##### example 1: run the hbase service with 3 regionserver nodes
```
$ docker run -e "branch=branch-1" chia7712/hbase:quickstart quickstart.sh 3
```
##### example 2: run the kafka service with 3 kafka brokers
```
$ docker run -e "branch=trunk" chia7712/kafka:quickstart quickstart.sh 3
```

## Auto-generated configuration
The quickstart.sh auto-generate the configuration when starting the service.

##### for zookeeper
* dataDir=/tmp/zookeeper
* log=/tmp/log/zookeeper.out

##### for kafka
* id=$node_index
* listeners=PLAINTEXT://:(9092+$node_index)
* log.dirs=/tmp/kafka-logs-$index
* broker.log=/tmp/log/broker$node_index.log

##### for hadoop

##### for hbase

###### master
* HBASE_PID_DIR=/tmp/master
* HBASE_LOG_DIR=/tmp/log/master
* com.sun.management.jmxremote.rmi.port=10101
* hbase.master.rmi.registry.port=10101
* hbase.master.rmi.connector.port=10101
* hbase.master.port=16000
* hbase.master.info.port=16010

###### regionserver
* HBASE_PID_DIR=/tmp/rs$node_index
* HBASE_LOG_DIR=/tmp/log/rs$node_index
* com.sun.management.jmxremote.rmi.port=(10102+$node_index)
* hbase.regionserver.rmi.registry.port=(10102+$node_index)
* hbase.regionserver.rmi.connector.port=(10102+$node_index)
* hbase.regionserver.port=(16020+$node_index)
* hbase.regionserver.info.port=(16030+$node_index)

## Projects location
* JAVA_HOME=/opt/java/default
* ZOOKEEPER_HOME=/opt/zookeeper/default
* KAFKA_HOME=/opt/kafka/default
* HADOOP_HOME=/opt/hadoop/default
* HBASE_HOME=/opt/hbase/default


## Authors
* **Chia-Ping Tsai (chia7712@is-land.com.tw)**

## License
This project is licensed under the MIT License