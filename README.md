# cquick
a tool to start kafka|hbase standalone service by docker container 

## Getting Started
All related projects and configs have been stored in the docker containers. All you need to do is to run the following command.

*kafka*
```
$ docker run -ti -e "BRANCH=trunk" chia7712/kafka:quickstart quickstart.sh
```
The **quickstart.sh** will execute the following ops.
1. download the **kafka** source code from https://github.com/apache/kafka
1. checkout the source code to **trunk** branch
1. build the source code and then untar the assembly
1. deploy **1 zookeeper** instance
1. generate the kafka broker configs and deploy **2 kafka brokers**
 
*hbase*
```
$ docker run -ti -e "BRANCH=master" chia7712/hbase:quickstart quickstart.sh
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
* Memory > 5G

### Installing

*kafka*
```
$ docker pull chia7712/kafka:quickstart
```
*hbase*
```
$ docker pull chia7712/hbase:quickstart
```
## Advanced Usage
There are some options configurable to user.

### How  to change the code
You can run the service based on the git revision, release src or release binary.

*example 1: run the hbase service based on branch-1*
```
$ docker run -ti -e "BRANCH=branch-1" chia7712/hbase:quickstart quickstart.sh
```
*example 2: run the hbase service based on hbase-1.4.3 src*
```
$ docker run -ti -e "BRANCH=https://www.apache.org/dist/hbase/1.4.3/hbase-1.4.3-src.tar.gz" chia7712/hbase:quickstart quickstart.sh
```
*example 3: run the hbase service based on hbase-1.4.3 binary*
```
$ docker run -ti -e "BRANCH=https://www.apache.org/dist/hbase/1.4.3/hbase-1.4.3-bin.tar.gz" chia7712/hbase:quickstart quickstart.sh
```

### How to apply the patch to the code
You can define the patch applying to the code before building and running

*example 1: run the hbase service based on master and patch*
```
$ docker run -ti -e "BRANCH=master" -v mypatch:/testpatch/patch chia7712/hbase:quickstart quickstart.sh
```
The quickstart.sh will check the exist of /testpatch/patch, and then apply it to the source code.

**NOTE:** You can only apply the patch to the code under git control.

### How to increase the running node
You can define the number of running regionserver|broker nodes. The min is 1 and max is 5.

*example 1: run the hbase service with 3 regionserver nodes*
```
$ docker run -ti -e "BRANCH=branch-1" chia7712/hbase:quickstart quickstart.sh 3
```
*example 2: run the kafka service with 3 kafka brokers*
```
$ docker run -ti -e "BRANCH=trunk" chia7712/kafka:quickstart quickstart.sh 3
```
### How to increase the heap size
You can change the heap size of JVM through adding the following environment variable to docker command

*kafka*
```
-e "KAFKA_HEAP_OPTS="-Xmx1G -Xms1G""
```
*hadoop*
```
-e "HADOOP_HEAPSIZE=2000"
```
*master*
```
-e "HBASE_MASTER_OPTS=-Xmx1G"
```
*regionserver*
```
-e "HBASE_REGIONSERVER_OPTS=-Xmx1G"
```

### How to assign public address to RMI server of JMX
```
-e "RMI_ADDRESS=XXX"
```

### How to change the default ports of kafka and hbase
You can change the "start" port of the services. For example: -e "BROKER_PORT=10000" means the first broker's port
is 10000, and then the next broker's port is 10001.

<table>
    <tr>
        <td>variables</td>
        <td>default</td>
        <td>description</td>
    </tr>
    <tr>
        <td>ZK_PORT</td>
        <td>2181</td>
        <td>the port used by zk. we won't start multi zk instances</td>
    </tr>
    <tr>
        <td>BROKER_PORT</td>
        <td>9090</td>
        <td>the port used by first broker</td>
    </tr>
    <tr>
        <td>BROKER_JMX_PORT</td>
        <td>9190</td>
        <td>the port used by first broker's jmx server</td>
    </tr>
    <tr>
        <td>WORKER_PORT</td>
        <td>10090</td>
        <td>the port used by first worker</td>
    </tr>
    <tr>
        <td>WORKER_JMX_PORT</td>
        <td>10190</td>
        <td>the port used by first worker's jmx server</td>
    </tr>
    <tr>
        <td>HBASE_PORT</td>
        <td>16000</td>
        <td>the port used by hbase master. the region server use next port</td>
    </tr>
    <tr>
        <td>HBASE_WEB_PORT</td>
        <td>16100</td>
        <td>the port used by hbase master's web server. the web server of region server use next port</td>
    </tr>
    <tr>
        <td>HBASE_JMX_PORT</td>
        <td>16200</td>
        <td>the port used by hbase master's jmx server. the jmx server of region server use next port</td>
    </tr>
</table>

## Auto-generated configuration
The following configurations used to start the services are auto-generated by quickstart.sh

*zookeeper*
* dataDir=/tmp/zookeeper
* log=/tmp/log/zookeeper.out
* clientPort=2181

*kafka broker*
* HEAP_SIZE=512M
* id=$node_index
* listeners=PLAINTEXT://:(9090+$node_index)
* jmxremote.port=(9190+$node_index)
* jmxremote.rmi.port=(9190+$node_index)
* log.dirs=/tmp/kafka-logs-$index
* broker.log=/tmp/log/broker$node_index.log

*kafka worker*
* HEAP_SIZE=512M
* id="worker-$node_index
* rest.port=(10090+$node_index)
* jmxremote.port=(10190+$node_index)
* jmxremote.rmi.port=(10190+$node_index)


*Hadoop namenode*
* HEAP_SIZE=1G
* HADOOP_LOG_DIR=/tmp/log/namenode
* fs.defaultFS=localhost:9000
* info.port=50070

*Hadoop datanode*
* HEAP_SIZE=1G
* HADOOP_LOG_DIR=/tmp/log/datanode
* data folder=/tmp/hadoop-{$USER}

*hbase master*
* HEAP_SIZE=1G
* HBASE_PID_DIR=/tmp/master
* HBASE_LOG_DIR=/tmp/log/master
* hbase.master.port=16000
* hbase.master.info.port=16100
* jmxremote.port=16200
* jmxremote.rmi.port=16200


*hbase regionserver*
* HEAP_SIZE=1G
* HBASE_PID_DIR=/tmp/rs$node_index
* HBASE_LOG_DIR=/tmp/log/rs$node_index
* hbase.regionserver.port=(16001+$node_index)
* hbase.regionserver.info.port=(16101+$node_index)
* jmxremote.port=(16201+$node_index)
* jmxremote.rmi.port=(16201+$node_index)

## Projects version
* zookeeper 3.4.10
* hadoop 2.5.1 (for hbase 1.x)
* hadoop 2.7.4 (for hbase 2.x+)

## Projects location
* JAVA_HOME=/opt/java/default
* ZOOKEEPER_HOME=/opt/zookeeper/default
* KAFKA_HOME=/opt/kafka/default
* HADOOP_HOME=/opt/hadoop/default
* HBASE_HOME=/opt/hbase/default

**NOTE:** The log of all instances are stored in /tmp/log 

## PATH
The following folders are added to the PATH.
* $JAVA_HOME/bin
* $ZOOKEEPER_HOME/bin
* $KAFKA_HOME/bin
* $HADOOP_HOME/bin
* $HADOOP_HOME/sbin
* $HBASE_HOME/bin

## Authors
* **Chia-Ping Tsai (chia7712@gmail.com)**

## License
This project is licensed under the MIT License
