#!/bin/bash
set -e

[[ "$1" != 'controller' ]] && exit 0

# stop timeline server
$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop timelineserver
