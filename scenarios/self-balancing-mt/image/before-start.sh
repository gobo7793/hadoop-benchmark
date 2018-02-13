#!/bin/bash
set -e

echo "Stopping processes before startup..."
echo "[$0]: *** Stopping all processes ***"

[[ -f /before-stop.sh ]] && /before-stop.sh $mode
case "$mode" in
controller)
  $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop namenode
  $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop secondarynamenode
  $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop resourcemanager
  $HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh --config $HADOOP_CONF_DIR stop historyserver
;;
compute)
  $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs stop datanode
  $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop nodemanager
;;
esac
[[ -f /after-stop.sh ]] && /after-stop.sh $mode

echo "[$0]: *** All processes have been stopped ***"
