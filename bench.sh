#!/bin/bash

DIR=~/hadoop-benchmark
TERM=xterm
export TERM

cd "$DIR"

declare -r script_name="$(basename $0)"
debug="true"

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

start_jobclient_tests(){
    log "Starting benchmark jobclient test: $1"
    
    $DIR/benchmarks/hadoop-jobclient-tests/run.sh "$@"
}

start_mapreduce_examples(){
    log "Starting benchmark mapreduce example: $1"
    
    $DIR/benchmarks/hadoop-mapreduce-examples/run.sh "$@"
}

start_hibench(){
    log "Starting Intel HiBench benchmarks: $@"
    
    $DIR/benchmarks/hibench/run.sh "$@"
}

start_swim(){
    log "Starting SWIM jobs"
    
    $DIR/benchmarks/swim/run.sh
}

print_help(){
cat <<EOM
Usage: $0 [OPTIONS] COMMAND

Options:
    -h, --help              Prints this help
    -q, --quiet             Do not print which commands are executed

Commands:
    mapreduce [args]        runs mapreduce example programs or
                              no args to list all available examples
    pi                      runs pi calculation mapreduce example
    jobclient [args]        runs jobclient test programs or
                              no args to list all available tests
    hibench [workloads]     runs Intel HiBench benchmarks with given workloads
                              see github for list of all workloads
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
        -f|--force)
            log "Forcing docker commands if available"
            force="true"
            shift
            ;;
        mapreduce)
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

$command | sed -r "s/\x1b[\[|\(][0-9;]*[a-zA-Z]//g"
