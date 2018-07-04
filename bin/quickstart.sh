#!/usr/bin/env bash

#------------------------------------[check the arguments]------------------------------------#
if [ ! -n "$BRANCH" ]; then
  echo "YOU must define the BRANCH"
  echo "1) url to src or binary."
  echo "2) git revision or branch"
  exit
fi

if [ ! -n "$PROJECT" ]; then
  if [[ "${BRANCH}" == *kafka* ]]; then
    PROJECT="kafka"
  elif [[ "${BRANCH}" == *hbase* ]]; then
    PROJECT="hbase"
  else
    echo "YOU don't set PROJECT, and we can't guess the project according to the BRANCH:$BRANCH"
  fi
fi

if [ "$PROJECT" != "kafka" ] && [ "$PROJECT" != "hbase" ]; then
  echo "Unsupported project:$PROJECT"
  exit
fi
#------------------------------------[define the functions and arguments]------------------------------------#
BINARY_ROOT_FOLDER="/opt/$PROJECT"
HADOOP_BINARY_ROOT_FOLDER="/opt/hadoop"
NODE_COUNT_MIN=1
NODE_COUNT_MAX=5
NODE_COUNT_DEFAULT=2
##----------------[kafka functions]----------------##
buildKafka() {
  sourcePath=$1
  gradle
  ./gradlew clean install releaseTarGz -x signArchives -PscalaVersion=2.12
  # kafak assembly includes the *site-docs*.tgz
  binarypath=$(find "$sourcepath/core/build/distributions/" -maxdepth 1 -type f -name "*.tgz" -not -path "*site*")
  tar -zxf $binarypath -C $BINARY_ROOT_FOLDER
  cd ~/
  rm -rf $sourcepath
}

startKafka() {
  # set kafka home
  KAFKA_ASSEMBLY=$(find "$BINARY_ROOT_FOLDER" -maxdepth 1 -type d -name "kafka_*")
  ln -s $KAFKA_ASSEMBLY $BINARY_ROOT_FOLDER/default
  KAFKA_HOME=$BINARY_ROOT_FOLDER/default

  # set Env
  echo "export KAFKA_HOME=$KAFKA_HOME" >> $HOME/.bashrc
  echo "export ZOOKEEPER_HOME=$ZOOKEEPER_HOME" >> $HOME/.bashrc
  echo "export JAVA_HOME=$JAVA_HOME" >> $HOME/.bashrc
  echo "export PATH=\$PATH:\$KAFKA_HOME/bin:\$ZOOKEEPER_HOME/bin" >> $HOME/.bashrc

  # deploy zookeeper config
  cp $CQUICK_HOME/conf/zookeeper/* $ZOOKEEPER_HOME/conf/
  echo "clientPort=$3" >> $ZOOKEEPER_HOME/conf/zoo.cfg

  mkdir /tmp/log
  # start zookeeper
  # make zookeeper log to /tmp
  cd /tmp/log
  $ZOOKEEPER_HOME/bin/zkServer.sh start

  # deploy zookeeper config
  cp $CQUICK_HOME/conf/kafka/* $KAFKA_HOME/config/

  # START kafka brokers
  # TODO: just run the kafka server in the background?
  rmiHostname=$2
  END=$1
  index=0
  brokerPort=$4
  jmxPort=$5
  brokerList=""
  while [[ $index -lt $END ]]
  do
    export KAFKA_JMX_OPTS="-Djava.rmi.server.hostname=$rmiHostname -Dcom.sun.management.jmxremote.port=$jmxPort -Dcom.sun.management.jmxremote.rmi.port=$jmxPort -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
    cp $KAFKA_HOME/config/server.properties "$KAFKA_HOME/config/server$index.properties"
    echo "broker.id=$index" >> "$KAFKA_HOME/config/server$index.properties"
    echo "listeners=PLAINTEXT://:$brokerPort" >> "$KAFKA_HOME/config/server$index.properties"
    echo "log.dirs=/tmp/kafka-logs-$index" >> "$KAFKA_HOME/config/server$index.properties"
    $KAFKA_HOME/bin/kafka-server-start.sh "$KAFKA_HOME/config/server$index.properties" > "/tmp/log/broker-$index.log" 2>&1 &
    brokerList=$brokerList",localhost:$brokerPort"
    ((index = index + 1))
    ((brokerPort = brokerPort+ 1))
    ((jmxPort = jmxPort + 1))
  done

  # START kafka wokrers
  index=0
  workerPort=$6
  jmxPort=$7
  while [[ $index -lt $END ]]
  do
    export KAFKA_JMX_OPTS="-Djava.rmi.server.hostname=$rmiHostname -Dcom.sun.management.jmxremote.port=$jmxPort -Dcom.sun.management.jmxremote.rmi.port=$jmxPort -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
    cp $KAFKA_HOME/config/connect-distributed.properties "$KAFKA_HOME/config/connect-distributed$index.properties"
    echo "worker.id=worker-$index" >> "$KAFKA_HOME/config/connect-distributed$index.properties"
    echo "bootstrap.servers=$brokerList" >> "$KAFKA_HOME/config/connect-distributed$index.properties"
    echo "rest.port=$workerPort" >> "$KAFKA_HOME/config/connect-distributed$index.properties"
    $KAFKA_HOME/bin/connect-distributed.sh "$KAFKA_HOME/config/connect-distributed$index.properties" > "/tmp/log/worker-$index.log" 2>&1 &
    ((index = index + 1))
    ((workerPort = workerPort+ 1))
    ((jmxPort = jmxPort + 1))
  done
}

##----------------[hbase functions]----------------##
buildHBase() {
  sourcePath=$1
  cd $sourcepath
  mvn clean install -DskipTests assembly:single
  binarypath=$(find "$sourcepath/hbase-assembly/target/" -maxdepth 1 -type f -name "*.gz")
  tar -zxf $binarypath -C $BINARY_ROOT_FOLDER
  cd ~/
  rm -rf $sourcepath
}

startHBase() {
  # set hbase home
  HBASE_ASSEMBLY=$(find "$BINARY_ROOT_FOLDER" -maxdepth 1 -type d -name "hbase-*")
  ln -s $HBASE_ASSEMBLY $BINARY_ROOT_FOLDER/default
  HBASE_HOME=$BINARY_ROOT_FOLDER/default

  # set hadoop home
  # Downloading the dist hadoop is too slow so the dist hadoop has been download to docker image
  OLD_HADOOP=$(find "$HBASE_HOME/lib/" -maxdepth 1 -type f -name "hadoop-*2.5*")
  if [ -n "$OLD_HADOOP" ]; then
    ln -s $HADOOP_BINARY_ROOT_FOLDER/hadoop-2.5.1 $HADOOP_BINARY_ROOT_FOLDER/default
  else
    ln -s $HADOOP_BINARY_ROOT_FOLDER/hadoop-2.7.4 $HADOOP_BINARY_ROOT_FOLDER/default
  fi
  HADOOP_HOME=$HADOOP_BINARY_ROOT_FOLDER/default

  # set Env
  echo "export ZOOKEEPER_HOME=$ZOOKEEPER_HOME" >> $HOME/.bashrc
  echo "export HADOOP_HOME=$HADOOP_HOME" >> $HOME/.bashrc
  echo "export HBASE_HOME=$HBASE_HOME" >> $HOME/.bashrc
  echo "export JAVA_HOME=$JAVA_HOME" >> $HOME/.bashrc
  echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$HBASE_HOME/bin:\$ZOOKEEPER_HOME/bin" >> $HOME/.bashrc

  # build hperf
  mkdir $COMPONENT_HOME/hperf
  git clone https://github.com/chia7712/hperf.git $COMPONENT_HOME/hperf

  # deploy zookeeper config
  cp $CQUICK_HOME/conf/zookeeper/* $ZOOKEEPER_HOME/conf/
  echo "clientPort=$3" >> $ZOOKEEPER_HOME/conf/zoo.cfg

  # start zookeeper
  mkdir /tmp/log
  # start zookeeper
  # make zookeeper log to /tmp
  cd /tmp/log
  $ZOOKEEPER_HOME/bin/zkServer.sh start

  # deploy hadoop config
  cp $CQUICK_HOME/conf/hadoop/* $HADOOP_HOME/etc/hadoop/

  # start hadoop
  $HADOOP_HOME/bin/hdfs namenode -format
  export HADOOP_LOG_DIR="/tmp/log/namenode"
  $HADOOP_HOME/sbin/hadoop-daemon.sh start namenode
  export HADOOP_LOG_DIR="/tmp/log/datanode"
  $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode

  # deploy hbase's config
  cp $CQUICK_HOME/conf/hbase/* $HBASE_HOME/conf/

  # start hbase
  rmiHostname=$2
  hbasePort=$4
  hbaseWebPort=$5
  jmxPort=$6
  export HBASE_MASTER_OPTS="$HBASE_MASTER_OPTS -Djava.rmi.server.hostname=$rmiHostname"
  export HBASE_PID_DIR=/tmp/master
  export HBASE_LOG_DIR=/tmp/log/master
  $HBASE_HOME/bin/hbase-daemon.sh start master \
    -Dhbase.master.port=$hbasePort \
	-Dhbase.master.info.port=$hbaseWebPort \
    -Dmaster.rmi.registry.port=$jmxPort \
	-Dmaster.rmi.connector.port=$jmxPort
  ((hbasePort = hbasePort + 1))
  ((hbaseWebPort = hbaseWebPort+ 1))
  ((jmxPort = jmxPort + 1))

  END=$1
  index=0
  while [[ $index -lt $END ]]
  do
    export HBASE_REGIONSERVER_OPTS="$HBASE_REGIONSERVER_OPTS -Djava.rmi.server.hostname=$rmiHostname"
    export HBASE_PID_DIR="/tmp/rs$index"
    export HBASE_LOG_DIR="/tmp/log/rs$index"
    $HBASE_HOME/bin/hbase-daemon.sh start regionserver \
      -Dhbase.regionserver.port=$hbasePort \
	  -Dhbase.regionserver.info.port=$hbaseWebPort \
      -Dregionserver.rmi.registry.port=$jmxPort \
	  -Dregionserver.rmi.connector.port=$jmxPort
	((index = index + 1))
	((hbasePort = hbasePort + 1))
	((hbaseWebPort = hbaseWebPort+ 1))
	((jmxPort = jmxPort + 1))
  done
}

#------------------------------------[ok, all LGTM. Trying to build the services]------------------------------------#
if [ ! -d "$BINARY_ROOT_FOLDER" ]; then
  mkdir $BINARY_ROOT_FOLDER
fi

# generate binary
if [[ "${BRANCH}" == http* ]]; then
  wget $BRANCH -P /tmp
  distname=$(basename "$BRANCH")
  distpath=/tmp/$distname
  if [[ "${distname}" == *src* ]]; then
    # prepare the source code
    tar -zxf $distpath -C /tmp/
	rm -f $distpath
	sourcepath=$(find "/tmp/" -maxdepth 1 -type d -name "$PROJECT*")
	# we will build the source later
  else
    # use the dist binary
	tar -zxf $distpath -C $BINARY_ROOT_FOLDER
    rm -f $distpath
  fi
else
  # if the father docker has download the kafka source code, we use it directly.
  if [ -d "/testpatch/$PROJECT" ]; then
    sourcepath=/testpatch/$PROJECT
  else
    sourcepath=/tmp/$PROJECT
	git clone https://github.com/apache/$PROJECT $sourcepath
  fi
  cd $sourcepath
  git checkout -- . | git clean -df
  git checkout $BRANCH
  git pull
  if [ -f /testpatch/patch ]; then
    git apply /testpatch/patch --stat
    git apply /testpatch/patch
  else
    echo "no patch file"
  fi
  # we will build the source later
fi

# build the binary by source
if [ ! -z ${sourcepath+x} ] && [ -d "$sourcepath" ]; then
  cd $sourcepath
  if [ "$PROJECT" == "kafka" ]; then
	buildKafka "$sourcepath"
  elif [ "$PROJECT" == "hbase" ]; then
    buildHBase "$sourcepath"
  else
    echo "Unsupported project"
    exit
  fi
fi

# calculate the count of nodes
nodeCount=$NODE_COUNT_DEFAULT
# replace the default value only when the passed arg is integer
if [ "$1" -eq "$1" ] 2>/dev/null; then
  nodeCount=$1
fi
if [ "$nodeCount" -gt "$NODE_COUNT_MAX" ]; then
  nodeCount=NODE_COUNT_MAX
fi
if [ "$nodeCount" -lt "$NODE_COUNT_MIN" ]; then
  nodeCount=NODE_COUNT_MIN
fi

rmiHostname=""
if [ -z "$RMI_ADDRESS" ]; then
  rmiHostname="$HOSTNAME"
else
  rmiHostname="$RMI_ADDRESS"
fi

zkPort=""
if [ -z "$ZK_PORT" ]; then
  zkPort="2181"
else
  zkPort="$ZK_PORT"
fi

if [ "$PROJECT" == "kafka" ]; then
  brokerPort=""
  if [ -z "$BROKER_PORT" ]; then
    brokerPort="9090"
  else
    brokerPort="$BROKER_PORT"
  fi
  brokerJmxPort=""
  if [ -z "$BROKER_JMX_PORT" ]; then
    brokerJmxPort="9190"
  else
    brokerJmxPort="$BROKER_JMX_PORT"
  fi
  workerPort=""
  if [ -z "$WORKER_PORT" ]; then
    workerPort="10090"
  else
    workerPort="$WORKER_PORT"
  fi
  workerJmxPort=""
  if [ -z "$WORKER_JMX_PORT" ]; then
    workerJmxPort="10190"
  else
    workerJmxPort="$WORKER_JMX_PORT"
  fi
  startKafka $nodeCount $rmiHostname $zkPort $brokerPort $brokerJmxPort $workerPort $workerJmxPort
elif [ "$PROJECT" == "hbase" ]; then
  hbasePort=""
  if [ -z "$HBASE_PORT" ]; then
    hbasePort="16000"
  else
    hbasePort="$HBASE_PORT"
  fi
  hbaseWebPort=""
  if [ -z "$HBASE_WEB_PORT" ]; then
    hbaseWebPort="16100"
  else
    hbaseWebPort="$HBASE_WEB_PORT"
  fi
  hbaseJmxPort=""
  if [ -z "$HBASE_JMX_PORT" ]; then
    hbaseJmxPort="16200"
  else
    hbaseJmxPort="$HBASE_JMX_PORT"
  fi
  startHBase $nodeCount $rmiHostname $zkPort $hbasePort $hbaseWebPort $hbaseJmxPort
else
  echo "Unsupported project"
  exit
fi

exec bash

