#!/bin/bash

DIR=~/hadoop-benchmark
TERM=xterm
export TERM
CONFIG=masterthesis
export CONFIG
CLUSTERSH="$DIR/cluster.sh"

#(docker-machine ls -q | grep '^local-hadoop-controller$') > /dev/null
#if [[ $? -eq 0 ]]
#then
#    eval $(docker-machine env --swarm local-hadoop-controller)
#fi

cd "$DIR"

declare -r script_name="$(basename $0)"
force="false"
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

do_clustersh(){
    q=
    f=
    if [[ "$debug" == "false" ]]
    then
        $q="-q"
    fi
    if [[ "$force" == "true" ]]
    then
        $f="-f"
    fi
    
    do="$CLUSTERSH $q $f $1"
    $do
}

start_cluster(){
    log "Starting cluster"
    
    do_clustersh "start-cluster"
}

stop_cluster(){
    log "Stopping cluster"
    
    do_clustersh "stop-cluster"
}

destroy_cluster(){
    log "Destroying cluster"
    
    do_clustersh "destroy-cluster"
    vboxmanage hostonlyif remove vboxnet0
}

start_hadoop(){
    log "Starting hadoop"
    
    do_clustersh "start-hadoop"
}

stop_hadoop(){
    log "Stopping hadoop"
    
    do_clustersh "stop-hadoop"
}

destroy_hadoop(){
    log "Destroying hadoop and removing hadoop docker images"
    
    do_clustersh "destroy-hadoop"
    docker rmi hadoop-benchmark/self-balancing-example
}

start_machine(){
    log "Starting docker-machine: local-hadoop-compute-$1"
    
    docker-machine start local-hadoop-compute-$1
}

stop_machine(){
    log "Stopping docker-machine: local-hadoop-compute-$1"
    
    docker-machine stop local-hadoop-compute-$1
}

start_node(){
    log "Starting Node: compute-$1"
    
    docker $(docker-machine config local-hadoop-compute-"$1") start compute-$1
}

stop_node(){
    log "Stopping Node: compute-$1"
    
    docker $(docker-machine config local-hadoop-compute-"$1") stop compute-$1
}

start_net(){
    log "Enable network adapter of node: compute-$1"
    
    docker $(docker-machine config local-hadoop-compute-"$1") network connect hadoop-net compute-$1
#    vboxmanage controlvm local-hadoop-compute-$1 nic1 nat
#    vboxmanage controlvm local-hadoop-compute-$1 nic2 hostonly vboxnet0
}

stop_net(){
    log "Disable network adapter of node: compute-$1"
    
    docker $(docker-machine config local-hadoop-compute-"$1") network disconnect hadoop-net compute-$1
#    vboxmanage controlvm local-hadoop-compute-$1 nic1 null
#    vboxmanage controlvm local-hadoop-compute-$1 nic2 null
}

start_mapreduce_examples(){
    log "Starting benchmark mapreduce example: $1"
    
    $DIR/benchmarks/hadoop-mapreduce-examples/run.sh "$@"
}

start_hibench(){
    log "Starting Intel HiBench benchmarks"
    
    $DIR/benchmarks/hibench/run.sh
}

start_swim(){
    log "Starting SWIM jobs"
    
    $DIR/benchmarks/swim/run.sh
}

hadoop_console(){
    log "Using hadoop console command: $@"
    
    #./cluster.sh -q run-controller "$@"
    docker $(docker-machine config local-hadoop-controller) exec controller "$@"
    #docker exec controller "$@"
}

start(){
    log "starting cluster+hadoop"
    
    start_cluster
    start_hadoop
}

stop(){
    log "stopping hadoop+cluster"
    
    stop_hadoop
    stop_cluster
    
    if [[ $1 == '-s' ]]; then
        log "shutdown computer"
        
        shutdown -P now
    fi
}

cluster_control(){
    cmd=$1
    machine=$2
    
    case "$cmd" in
        start)
            if [[ -z "$machine" ]]
            then
                start_cluster
            else
                start_machine $machine
            fi
            ;;
        stop)
            if [[ -z "$machine" ]]
            then
                stop_cluster
            else
                stop_machine $machine
            fi
            ;;
        destroy)
            destroy_cluster
            ;;
        *)
            error "cluster $cmd: unknown command or argument"
            print_help
            ;;
    esac
}

hadoop_control(){
    cmd=$1
    node=$2
    
    case "$cmd" in
        start)
            if [[ -z "$node" ]]
            then
                start_hadoop
            else
                start_node $node
            fi
            ;;
        stop)
            if [[ -z "$node" ]]
            then
                stop_hadoop
            else
                stop_node $node
            fi
            ;;
        destroy)
            destroy_hadoop
            ;;
        *)
            error "hadoop $cmd: unknown command or argument"
            print_help
            ;;
    esac
}

networking_control(){
    cmd=$1
    node=$2
    
    case "$cmd" in
        start)
            start_net $node
            ;;
        stop)
            stop_net $node
            ;;
        *)
            error "net $cmd: unknown command or argument"
            print_help
            ;;
    esac
}

benchmark_control(){
    bench=$1
    shift
    
    case "$bench" in
        mapreduce)
            start_mapreduce_examples "$@"
            ;;
        pi)
            start_mapreduce_examples "pi" "20" "1000"
            ;;
        hibench)
            start_hibench
            ;;
        swim)
            start_swim
            ;;
        *)
            error "bench $bench: unknown command or argument"
            print_help
            ;;
    esac
}

print_help(){
cat <<EOM
Usage: $0 [OPTIONS] COMMAND

Options:
    -c, --config            Use the given config
    -f, --force             Use '-f' in docker commands where applicable
    -h, --help              Prints this help
    -q, --quiet             Do not print which commands are executed

Commands:
    start                   starting cluster+hadoop
    stop [-s]               stopping hadoop+cluster and
                            optionally shutdowns the computer (needs sudo)
    
    cluster start [node-id] starting cluster or the given machine
    cluster stop [node-id]  stopping hadoop or the given machine
    cluster destroy         destroys the cluster
    
    hadoop start [node-id]  starting  hadoop or the given node
    hadoop stop [node-id]   stopping hadoop or the given node
    hadoop destroy          destroys the cluster
    
    net start <node-id>     enables networking interfaces on the given node
    net stop <node-id>      disables networking interfaces on the given node
    
    bench                   executes the given benchmark:
        mapreduce [args]    runs mapreduce example programs or
                              no args to list all available examples
        pi                  runs pi calculation mapreduce example
        hibench             runs Intel HiBench benchmarks
        swim                runs the SWIM jobs
    
    cmd <cmd>               executes the given command on hadoop controller
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
        -c|--config)
            if [[ -e $2 ]]; then
                CONFIG=$2
                log "Using config $2"
            else
                log "Config file $2 not found"
            fi
            shift 2
            ;;
        start)
            command=start
            break
            ;;
        stop)
            command=stop
            break
            ;;
        cluster)
            command=cluster_control
            break
            ;;
        hadoop)
            command=hadoop_control
            break
            ;;
        net)
            command=networking_control
            break
            ;;
        bench)
            command=benchmark_control
            break
            ;;
        cmd)
            command=hadoop_console
            break
            ;;
        *)
            error "$1: unknown command or argument"
            command=print_help
            ;;
    esac
done

shift

$command "$@" | sed -r "s/\x1b[\[|\(][0-9;]*[a-zA-Z]//g"
