#!/bin/bash
set -e

[[ "$1" != 'controller' ]] && exit 0

# start timeline server
$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start timelineserver

# start self-balancing approach
java -jar Self-balance.jar &
