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
  filename=$(basename "$KAFKA_BRANCH")
  wget $KAFKA_BRANCH
  tar -zxvf $filename -C /opt/kafka
  rm -f $filename
else
  cd $KAFKA_SOURCE
  git checkout -- . | git clean -df
  echo "checkout to $KAFKA_BRANCH"
  git checkout $KAFKA_BRANCH
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
  filename=$(find "$KAFKA_SOURCE/core/build/distributions/" -maxdepth 1 -type f -name "*SNAPSHOT.tgz")
  tar -zxvf $filename -C /opt/kafka
fi

# set kafka home
KAFKA_ASSEMBLY=$(find "/opt/kafka" -maxdepth 1 -type d -name "kafka*SNAPSHOT")
echo "[DEBUG] $KAFKA_ASSEMBLY"
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
$KAFKA_HOME/bin/afka-server-start.sh $KAFKA_HOME/config/server.properties

exec bash
