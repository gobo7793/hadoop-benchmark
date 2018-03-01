#!/bin/bash
set -e
source $(dirname $0)/../common.sh

# benchmark settings
ALL_BENCHMARKS="micro.wordcount micro.sort micro.terasort micro.sleep"

base=$(dirname "$(cd "$(dirname "$0")"; pwd)/$(basename "$0")")

# build the image at the controller node
[ ! -z $(docker $(docker-machine config local-hadoop-controller) images -q hadoop-benchmark-hibench) ] || docker $controller_conn build -t hadoop-benchmark-hibench "$base/image"

if [[ $# -lt 1 ]]; then
  BENCHMARKS="--benchmarks $ALL_BENCHMARKS"
else
  BENCHMARKS="$@"
fi

# run the benchmark at the controller node
cmd="docker $controller_conn run \
  -t \
  --rm \
  --net hadoop-net \
  --name hadoop-benchmark-hibench \
  -h hadoop-benchmark-hibench \
  hadoop-benchmark-hibench \
  $BENCHMARKS"
$cmd
