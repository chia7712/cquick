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
    # prepare the source code
    tar -zxvf $distpath -C /tmp/
	rm -f $distpath
	sourcepath=$(find "/tmp/" -maxdepth 1 -type d -name "kafka*")
	# we will build the source later
  fi
else
  # if the father docker has download the kafka source code, we use it directly.
  if [ -d "$KAFKA_SOURCE" ]; then
    sourcepath=$KAFKA_SOURCE
  else
    sourcepath=/tmp/kafka
	git clone https://github.com/apache/kafka $sourcepath
  fi
  cd $sourcepath
  git checkout -- . | git clean -df
  git checkout $KAFKA_BRANCH
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
if [ -d "$sourcepath" ]; then
  cd $sourcepath
  gradle
  ./gradlew clean
  ./gradlew releaseTarGz -x signArchives
  # kafak assembly includes the *site-docs*.tgz
  binarypath=$(find "$sourcepath/core/build/distributions/" -maxdepth 1 -type f -name "*.tgz" -not -path "*site*")
  tar -zxvf $binarypath -C /opt/kafka
  cd ~/
  rm -rf $sourcepath
fi
  
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
cp $CQUICK_HOME/conf/zookeeper/* $ZOOKEEPER_HOME/conf/

# start zookeeper
$ZOOKEEPER_HOME/bin/zkServer.sh start

# START kafka
# TODO: just run the kafka server in the background
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > /dev/null 2>&1 &

exec bash
