#!/bin/bash
rm -r workGenLogs
mkdir workGenLogs
./run-job-0.sh &
sleep 4
./run-job-1.sh &
sleep 5
./run-job-2.sh &
sleep 2
./run-job-3.sh &
sleep 7
./run-job-4.sh &
sleep 11
./run-job-5.sh &
sleep 6
./run-job-6.sh &
sleep 14
./run-job-7.sh &
sleep 6
./run-job-8.sh &
sleep 9
./run-job-9.sh &
sleep 14
./run-job-10.sh &
sleep 10
./run-job-11.sh &
sleep 12
./run-job-12.sh &
sleep 17
./run-job-13.sh &
sleep 12
./run-job-14.sh &
sleep 6
./run-job-15.sh &
sleep 6
./run-job-16.sh &
sleep 12
./run-job-17.sh &
sleep 6
./run-job-18.sh &
sleep 2
./run-job-19.sh &
sleep 5
./run-job-20.sh &
sleep 2
./run-job-21.sh &
sleep 17
./run-job-22.sh &
sleep 20
./run-job-23.sh &
sleep 8
./run-job-24.sh &
sleep 3
./run-job-25.sh &
sleep 15
./run-job-26.sh &
sleep 13
./run-job-27.sh &
sleep 3
./run-job-28.sh &
sleep 9
./run-job-29.sh &
sleep 10
./run-job-30.sh &
sleep 4
./run-job-31.sh &
sleep 1
./run-job-32.sh &
sleep 5
./run-job-33.sh &
sleep 11
./run-job-34.sh &
sleep 10
./run-job-35.sh &
sleep 18
./run-job-36.sh &
sleep 1
./run-job-37.sh &
sleep 0
./run-job-38.sh &
sleep 1
./run-job-39.sh &
sleep 1
./run-job-40.sh &
sleep 4
./run-job-41.sh &
sleep 10
./run-job-42.sh &
sleep 7
./run-job-43.sh &
sleep 13
./run-job-44.sh &
sleep 12
./run-job-45.sh &
sleep 4
./run-job-46.sh &
sleep 17
./run-job-47.sh &
sleep 8
./run-job-48.sh &
sleep 11
./run-job-49.sh &
sleep 33
# max input 171246518
# inputPartitionSize 67108864
# inputPartitionCount 10

for job in `jobs -p`
do
  echo "Waiting for $job to finish"
  wait $job
done

logs="workGenLogs-$(date +"%Y%m%d-%H%M").tgz"
tar cfvz "$logs" "$SWIM_HOME/workGenLogs"
hdfs dfs -put "$logs" "/user/root/$logs"

echo "Benchmarks finished"
echo "Logs uploaded to HDFS: /user/root/$logs"
