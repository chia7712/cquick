#!/usr/bin/env bash

if [ ! -n "$HBASE_BRANCH" ]; then
  echo "Define the HBASE_BRANCH. You can pass the url to source code also"
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

# generate hbase

if [[ "${HBASE_BRANCH}" == http* ]]; then
  filename=$(basename "$HBASE_BRANCH")
  wget $HBASE_BRANCH
  tar -zxvf $filename -C $COMPONENT_HOME
  rm -f $filename
else
  cd /testpatch/hbase
  git checkout -- . | git clean -df
  echo "checkout to $HBASE_BRANCH"
  git checkout $HBASE_BRANCH
  git pull
  if [ -f /testpatch/patch ]; then
    git apply /testpatch/patch --stat
    git apply /testpatch/patch
  else
    echo "no patch file"
  fi
  mvn clean install -DskipTests assembly:single
  filename=$(find "/testpatch/hbase/hbase-assembly/target/" -type f -maxdepth 1 -name "*.gz")
  tar -zxvf $filename -C $COMPONENT_HOME
fi
HBASE_HOME=$(find "$COMPONENT_HOME" -type d -maxdepth 1 -name "hbase-*")
HADOOP_HOME=$COMPONENT_HOME/hadoop-2.7.4
# set Env
echo "export HADOOP_HOME=$HADOOP_HOME" >> $HOME/.bashrc
echo "export HBASE_HOME=$HBASE_HOME" >> $HOME/.bashrc
echo "export JAVA_HOME=$JAVA_HOME" >> $HOME/.bashrc
echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$HBASE_HOME/bin" >> $HOME/.bashrc

# build hperf
cd $HOME
git clone https://github.com/chia7712/hperf.git

# deploy hadoop's config
cp $HQUICK_HOME/conf/hadoop/* $HADOOP_HOME/etc/hadoop/

# start hadoop
$HADOOP_HOME/bin/hdfs namenode -format
$HADOOP_HOME/sbin/start-dfs.sh

# deploy hbase's config
cp $HQUICK_HOME/conf/hbase/* $HBASE_HOME/conf/

# start hbase
$HBASE_HOME/bin/start-hbase.sh

exec bash
