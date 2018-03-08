#!/usr/bin/env bash

if [ ! -n "$KAFKA_BRANCH" ]; then
  echo "Define the KAFKA_BRANCH. You can pass the URL to source code also"
  exit
fi
# generate ssh key
ssh-keygen -t rsa -P '' -f $HOME/.ssh/id_rsa
cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
chmod 0600 $HOME/.ssh/authorized_keys

# start ssh service
/etc/init.d/ssh start

# list the env variables
ssh localhost -o StrictHostKeyChecking=no "export"
ssh 0.0.0.0 -o StrictHostKeyChecking=no "export"

# generate kafka binary
mkdir /opt/kafka
if [[ "${KAFKA_BRANCH}" == http* ]]; then
  wget $KAFKA_BRANCH -P /tmp
  distname=$(basename "$KAFKA_BRANCH")
  distpath=/tmp/$distname
  if [[ "${distname}" == *bin* ]]; then
    # use the dist binary
	tar -zxvf $distpath -C /opt/kafka
    rm -f $distpath
  else
    # build the binary from dist source
    tar -zxvf $distpath -C /tmp/
	rm -f $distpath
	sourcepath=$(find "/tmp/" -maxdepth 1 -type d -name "kafka*")
	cd $sourcepath
    gradle
    ./gradlew clean
    ./gradlew releaseTarGz -x signArchives
    binarypath=$(find "$sourcepath/core/build/distributions/" -maxdepth 1 -type f -name "*.tgz")
    tar -zxvf $binarypath -C /opt/kafka
	cd ~/
	rm -rf $sourcepath
  fi
else
  sourcepath=""
  # if the father docker has download the kafka source code, we use it directly.
  if [ -d "$KAFKA_SOURCE" ]; then
    sourcepath=$KAFKA_SOURCE
  else
    sourcepath=/tmp/kafak
	git clone https://github.com/apache/kafak $sourcepath
  fi
  cd $sourcepath
  git checkout -- . | git clean -df
  git checkout $HBASE_BRANCH
  git pull
  if [ -f /testpatch/patch ]; then
    git apply /testpatch/patch --stat
    git apply /testpatch/patch
  else
    echo "no patch file"
  fi
  gradle
  ./gradlew clean
  ./gradlew releaseTarGz -x signArchives
  binarypath=$(find "$sourcepath/core/build/distributions/" -maxdepth 1 -type f -name "*.tgz")
  tar -zxvf $binarypath -C /opt/kafka
  cd ~/
  rm -rf $sourcepath
fi

  gradle
  ./gradlew clean
  ./gradlew releaseTarGz -x signArchives
  
# set kafka home
KAFKA_ASSEMBLY=$(find "/opt/kafka" -maxdepth 1 -type d -name "kafka*SNAPSHOT")
ln -s $KAFKA_ASSEMBLY /opt/kafka/default
KAFKA_HOME=/opt/kafka/default

# set Env
echo "export KAFKA_HOME=$KAFKA_HOME" >> $HOME/.bashrc
echo "export ZOOKEEPER_HOME=$ZOOKEEPER_HOME" >> $HOME/.bashrc
echo "export JAVA_HOME=$JAVA_HOME" >> $HOME/.bashrc
echo "export PATH=\$PATH:\$KAFKA_HOME/bin:\$ZOOKEEPER_HOME/bin" >> $HOME/.bashrc

# deploy zookeeper config
cp $HQUICK_HOME/conf/zookeeper/* $ZOOKEEPER_HOME/conf/

# start zookeeper
$ZOOKEEPER_HOME/bin/zkServer.sh start

# START kafka
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties

exec bash
