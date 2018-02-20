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

# generate hbase binary
mkdir /opt/hbase
if [[ "${HBASE_BRANCH}" == http* ]]; then
  filename=$(basename "$HBASE_BRANCH")
  wget $HBASE_BRANCH
  tar -zxvf $filename -C /opt/hbase
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
  tar -zxvf $filename -C /opt/hbase
fi

# set hbase home
HBASE_ASSEMBLY=$(find "/opt/hbase" -type d -maxdepth 1 -name "hbase-*")
ln -s $HBASE_ASSEMBLY /opt/hbase/default
HBASE_HOME=/opt/hbase/default

# set hadoop home
# Downloading the dist hadoop is too slow so the dist hadoop has been download to docker image
OLD_HADOOP=$(find "$HBASE_HOME/lib/" -type f -maxdepth 1 -name "hadoop-*2.5*")
if [ -n "$OLD_HADOOP" ]; then
  ln -s /opt/hadoop/hadoop-2.5.1 /opt/hadoop/default
else
  ln -s /opt/hadoop/hadoop-2.7.4 /opt/hadoop/default
fi
HADOOP_HOME=/opt/hadoop/default

# set Env
echo "export HADOOP_HOME=$HADOOP_HOME" >> $HOME/.bashrc
echo "export HBASE_HOME=$HBASE_HOME" >> $HOME/.bashrc
echo "export JAVA_HOME=$JAVA_HOME" >> $HOME/.bashrc
echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$HBASE_HOME/bin" >> $HOME/.bashrc

# build hperf
mkdir $COMPONENT_HOME/hperf
git clone https://github.com/chia7712/hperf.git $COMPONENT_HOME/hperf

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
