#!/usr/bin/env bash

if [ ! -n "$HBASE_BRANCH" ] || [ ! -n "$HBASE_ASSEMBLY" ]; then
  echo "Define the HBASE_BRANCH and HBASE_ASSEMBLY"
  exit
fi
# generate ssh key
ssh-keygen -t rsa -P '' -f $HOME/.ssh/id_rsa
cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
chmod 0600 $HOME/.ssh/authorized_keys

# start ssh service
/etc/init.d/ssh start

# set Env
echo "export HADOOP_HOME=$HADOOP_HOME" >> $HOME/.bashrc
echo "export HBASE_HOME=$HBASE_HOME" >> $HOME/.bashrc
echo "export JAVA_HOME=$JAVA_HOME" >> $HOME/.bashrc

# list the env variables
ssh localhost -o StrictHostKeyChecking=no "export"
ssh 0.0.0.0 -o StrictHostKeyChecking=no "export"

# generate hbase
ASSEMBLY_NAME=""
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
tar -zxvf /testpatch/hbase/hbase-assembly/target/$HBASE_ASSEMBLY-bin.tar.gz -C $HOME/
mv $HOME/$HBASE_ASSEMBLY $HOME/hbase

# build hperf
cd $HOME
git clone https://github.com/chia7712/hperf.git
cd $HOME/hperf
if [ -n "$HPERF_BRANCH" ]; then
  git checkout $HPERF_BRANCH
else
  echo "HPERF_BRANCH is unset. Use master branch instead"
  git checkout master
fi
gradle clean build -x test -q copyDeps

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