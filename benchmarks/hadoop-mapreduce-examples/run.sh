#!/bin/bash
set -e
source $(dirname $0)/../common.sh

if [[ $1 == "-t" ]]; then
  name="examples-$timestamp"
  shift
else
  name="hadoop-mapreduce-examples"
fi

cmd="docker $controller_conn run \
  -t \
  --rm \
  --net hadoop-net \
  --name $name \
  -h $name \
  hadoop-benchmark/self-balancing-mt \
  run \
  hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.1.jar $@"
echo $cmd
