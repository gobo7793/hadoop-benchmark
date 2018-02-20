#!/bin/bash
set -e
source $(dirname $0)/../common.sh

base=$(dirname "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")")

buildStartTime=`date`
buildStartTimeS=`date +%s`
docker $controller_conn build -t hadoop-benchmark-swim "$base/image"

execStartTime=`date`
execStartTimeS=`date +%s`
docker $controller_conn run \
  -it \
  --rm \
  --net hadoop-net \
  --name hadoop-benchmark-swim \
  -h hadoop-benchmark-swim \
  hadoop-benchmark-swim

execEndTime=`date`
execEndTimeS=`date +%s`

echo "buildStartTime=$buildStartTime"
echo "buildStartTimeS=$buildStartTimeS"
echo "execStartTime=$execStartTime"
echo "execStartTimeS=$execStartTimeS"
echo "execEndTime=$execEndTime"
echo "execEndTimeS=$execEndTimeS"
