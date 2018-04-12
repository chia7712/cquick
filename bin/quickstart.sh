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
  ./gradlew clean
  ./gradlew releaseTarGz -x signArchives -PscalaVersion=2.12
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

  mkdir /tmp/log
  # start zookeeper
  # make zookeeper log to /tmp
  cd /tmp/log
  $ZOOKEEPER_HOME/bin/zkServer.sh start

  # deploy zookeeper config
  cp $CQUICK_HOME/conf/kafka/* $KAFKA_HOME/config/

  # START kafka
  # TODO: just run the kafka server in the background?
  
  END=NODE_COUNT_DEFAULT
  if [ "$1" != "" ]; then
    END=$1
  fi
  if [ "$END" -ge "$NODE_COUNT_MAX" ]; then
    END=NODE_COUNT_MAX
  fi
  if [ "$END" -le "$NODE_COUNT_MIN" ]; then
    END=NODE_COUNT_MIN
  fi
  index=0
  brokerPort=9092
  while [[ $index -lt $END ]]
  do
    cp $KAFKA_HOME/config/server.properties "$KAFKA_HOME/config/server$index.properties"
	echo "broker.id=$index" >> "$KAFKA_HOME/config/server$index.properties"
	echo "listeners=PLAINTEXT://:$brokerPort" >> "$KAFKA_HOME/config/server$index.properties"
    $KAFKA_HOME/bin/kafka-server-start.sh "$KAFKA_HOME/config/server$index.properties" > "/tmp/log/broker$index.log" 2>&1 &
    ((index = index + 1))
	((brokerPort = brokerPort + 1))
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
  $HADOOP_HOME/sbin/hadoop-daemon.sh start namenode
  $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode

  # deploy hbase's config
  cp $CQUICK_HOME/conf/hbase/* $HBASE_HOME/conf/

  # start hbase
  export HBASE_PID_DIR=/tmp/master
  export HBASE_LOG_DIR=/tmp/log/master
  export HBASE_MASTER_OPTS="$HBASE_MASTER_OPTS -Dcom.sun.management.jmxremote.rmi.port=10101"
  $HBASE_HOME/bin/hbase-daemon.sh start master \
    -Dhbase.master.port=16000 \
	-Dhbase.master.info.port=16010 \
    -Dmaster.rmi.registry.port=10101 \
	-Dmaster.rmi.connector.port=10101
  END=NODE_COUNT_DEFAULT
  if [ "$1" != "" ]; then
    END=$1
  fi
  if [ "$END" -ge "$NODE_COUNT_MAX" ]; then
    END=NODE_COUNT_MAX
  fi
  if [ "$END" -le "$NODE_COUNT_MIN" ]; then
    END=NODE_COUNT_MIN
  fi
  index=0
  rsPort=16020
  rsInfoPort=16030
  rmiPort=10102
  while [[ $index -lt $END ]]
  do
    export HBASE_PID_DIR="/tmp/rs$index"
    export HBASE_LOG_DIR="/tmp/log/rs$index"
    export HBASE_REGIONSERVER_OPTS="$HBASE_REGIONSERVER_OPTS -Dcom.sun.management.jmxremote.rmi.port=$rmiPort"
    $HBASE_HOME/bin/hbase-daemon.sh start regionserver \
      -Dhbase.regionserver.port=$rsPort \
	  -Dhbase.regionserver.info.port=$rsInfoPort \
      -Dregionserver.rmi.registry.port=$rmiPort \
	  -Dregionserver.rmi.connector.port=$rmiPort
    ((index = index + 1))
	((rmiPort = rmiPort + 1))
	((rsPort = rsPort + 1))
	((rsInfoPort = rsInfoPort + 1))
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


if [ "$PROJECT" == "kafka" ]; then
  startKafka
elif [ "$PROJECT" == "hbase" ]; then
  startHBase $1
else
  echo "Unsupported project"
  exit
fi

exec bash

