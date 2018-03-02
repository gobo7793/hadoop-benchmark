#!/bin/bash
set -e

echo -n 'hibench.hdfs.data.dir ${hibench.hdfs.master}/' >> $HIBENCH_HOME/conf/hibench.conf
if [[ $1 == "--dir" ]]; then
  echo $2 >> $HIBENCH_HOME/conf/hibench.conf
  shift 2
else
  echo "HiBench" >> $HIBENCH_HOME/conf/hibench.conf
fi

case "$1" in
  --benchmarks)
    shift

    echo $@ | tr ' ' '\n' > $HIBENCH_HOME/conf/benchmarks.lst
    echo "Running benchmarks:"
    cat $HIBENCH_HOME/conf/benchmarks.lst
    $HIBENCH_HOME/bin/run_all.sh
  ;;
  *)
    exec "$@"
  ;;
esac

hdfs dfs -mkdir -p hdfs:///user/root/

report=$HIBENCH_HOME/hibench.report
dest="/user/root/hibench-$(date +"%Y%m%d-%H%M").report"
hdfs dfs -put "$report" "$dest"

echo "Benchmarks finished"
echo
cat "$report"
echo
echo "The report has been uploaded to HDFS: $dest"
echo "To download, run ./cluster.sh hdfs-download \"$dest\""

