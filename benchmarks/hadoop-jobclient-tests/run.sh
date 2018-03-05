#!/bin/bash
set -e
source $(dirname $0)/../common.sh

#if [[ $1 == "-t" ]]; then
#  name="jobclient-$timestamp"
#  shift
#else
#  name="hadoop-jobclient-tests"
#fi

#cmd="docker $controller_conn run \
#  -t \
#  --rm \
#  --net hadoop-net \
#  --name $name \
#  -h $name \
#  hadoop-benchmark/self-balancing-mt \
#  run \
#  hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.1.jar $@"
cmd="docker $controller_conn exec controller hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-2.7.1.jar $@"
$cmd
