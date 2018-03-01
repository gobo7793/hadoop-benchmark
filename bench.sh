#!/bin/bash

DIR=~/hadoop-benchmark
TERM=xterm
export TERM

cd "$DIR"

declare -r script_name="$(basename $0)"
debug="true"
timestamp="false"

log() {
  if [[ "$debug" == "true" ]]; then
    echo "[$script_name]: $@"
  fi
}

debug() {
  [[ "$debug" == "true" ]] && log $@
}

error() {
  echo >&2 "[$script_name]: $@"
}

start_benchmark(){
  bench=$1
  shift
  t=
  if [[ $timestamp == "true" ]]; then
    t="-t"
  fi
  $DIR/benchmarks/$bench/run.sh $t "$@"
}

start_mapreduce_examples(){
    log "Starting benchmark mapreduce example: $1"
    
    start_benchmark hadoop-mapreduce-examples "$@"
}

start_jobclient_tests(){
    log "Starting benchmark jobclient test: $1"
    
    start_benchmark hadoop-jobclient-tests "$@"
}

start_hibench(){
    log "Starting Intel HiBench: $@"
    
    start_benchmark hibench "$@"
}

start_swim(){
    log "Starting SWIM jobs"
    
    start_benchmark swim
}

print_help(){
cat <<EOM
Usage: $0 [OPTIONS] COMMAND

Options:
    -h, --help              Prints this help
    -q, --quiet             Do not print which commands are executed
    -t, --timestamp         Using timestamps for docker container names

Commands:
    example [args]          runs mapreduce example programs or
                              no args to list all available examples
    pi                      runs pi calculation mapreduce example
    jobclient [args]        runs jobclient test programs or
                              no args to list all available tests
    hibench [--benchmarks [args]]
                            runs Intel HiBench cmd or given benchmarks
                              see github for list of all benchmarks
                              or nothing to start micro workload
    swim                    runs the SWIM jobs
EOM
}

command=

if [[ -z $1 ]]; then
  command=print_help
fi
while [[ -z $command ]]; do
    case "$1" in
        -h|--help)
            command=print_help
            break
            ;;
        -q|--quiet)
            #log "Quiet output enabled"
            debug="false"
            shift
            ;;
        -t|--timestamp)
            log "Using timestamp docker container names"
            timestamp="true"
            shift
            ;;
        example)
            shift
            command="start_mapreduce_examples $@"
            ;;
        pi)
            command="start_mapreduce_examples pi 20 1000"
            ;;
        jobclient)
            shift
            command="start_jobclient_tests $@"
            ;;
        hibench)
            shift
            command="start_hibench $@"
            ;;
        swim)
            command="start_swim"
            ;;
        *)
            error "$1: unknown benchmark or argument"
            command=print_help
            ;;
    esac
done

$command #| sed -r "s/\x1b[\[|\(][0-9;]*[a-zA-Z]//g"
