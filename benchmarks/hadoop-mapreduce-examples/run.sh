#!/bin/bash
set -e
source $(dirname $0)/../common.sh

#original container:
#hadoop-benchmark/hadoop \

docker $controller_conn run \
  -t \
  --rm \
  --net hadoop-net \
  --name hadoop-mapreduce-examples \
  -h hadoop-mapreduce-examples \
  hadoop-benchmark/self-balancing-mt \
  run \
  hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.1.jar "$@"
