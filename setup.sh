#!/bin/bash

DIR=~/hadoop-benchmark
TERM=xterm
export TERM
CONFIG=masterthesis
export CONFIG
CLUSTERSH="$DIR/cluster.sh"

cd "$DIR"

[[ -f $CONFIG ]] && source $CONFIG
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

create_portforwarding(){
    machine=$1
    app=$2
    guestPort=$3
    if [[ -z $4 ]]; then
        hostPort=$3
    else
        hostPort=$4
    fi
    if [[ -z $5 ]]; then
        protocol="tcp"
    else
        protocol=$5
    fi

    if [[ -z $(VBoxManage showvminfo $CLUSTER_NAME_PREFIX-$machine | grep "name = $app, protocol = $protocol") ]]; then
        VBoxManage controlvm $CLUSTER_NAME_PREFIX-$machine natpf1 $app,$protocoll,,$hostPort,,$guestPort
    fi
}

start_cluster(){
    log "Starting cluster"
    
    do_clustersh "start-cluster"
    
    log "Adding port forwarding for consul (2376,3376,8500,7946,4789)"
    create_portforwarding consul docker 2376
    create_portforwarding consul swarm 3376
    create_portforwarding consul consul 8500
    create_portforwarding consul ovnet 7946
    create_portforwarding consul ovnetudp 7946 7946 udp
    create_portforwarding consul ovnet2 4789
    
    log "Adding port forwarding for RM (8088), TLS (8188), HDFS (50700), graphite (80->8080)"
    create_portforwarding controller RM 8088
    create_portforwarding controller TLS 8188
    create_portforwarding controller HDFS 50700
    create_portforwarding controller graphite 80 8080
}

stop_cluster(){
    log "Stopping cluster"
    
    do_clustersh "stop-cluster"
}

restart_cluster(){
    log "Restarting cluster"
    
    do_clustersh "restart-cluster"
}

destroy_cluster(){
    log "Destroying cluster"
    
    do_clustersh "destroy-cluster" \
        && vboxmanage hostonlyif remove vboxnet0
}

start_machine(){
    log "Starting docker-machine: $CLUSTER_NAME_PREFIX-compute-$1"
    
    docker-machine start $CLUSTER_NAME_PREFIX-compute-$1
}

stop_machine(){
    log "Stopping docker-machine: $CLUSTER_NAME_PREFIX-compute-$1"
    
    docker-machine stop $CLUSTER_NAME_PREFIX-compute-$1
}

restart_machine(){
    log "Restarting docker-machine: $CLUSTER_NAME_PREFIX-compute-$1"
    
    stop_machine $1 && start_machine $1
}

start_hadoop(){
    log "Starting hadoop"
    
    do_clustersh "start-hadoop"
}

stop_hadoop(){
    log "Stopping hadoop"
    
    do_clustersh "stop-hadoop"
}

restart_hadoop(){
    log "Restarting hadoop"
    
    stop_hadoop && start_hadoop
}

destroy_hadoop(){
    log "Destroying hadoop and removing hadoop docker images"
    
    do_clustersh "destroy-hadoop" \
        && docker $(docker-machine config --swarm $CLUSTER_NAME_PREFIX-controller) rmi hadoop-benchmark/self-balancing-example
}

start_node(){
    log "Starting Node: compute-$1"
    
    docker $(docker-machine config $CLUSTER_NAME_PREFIX-compute-"$1") start compute-$1
}

stop_node(){
    log "Stopping Node: compute-$1"
    
    docker $(docker-machine config $CLUSTER_NAME_PREFIX-compute-"$1") stop compute-$1
}

restart_node(){
    log "Restarting Node: compute-$1"
    
    stop_node $1 && start_node $1
}

ls_hadoop(){
    log "List running hadoop docker container"
    
    docker $(docker-machine config --swarm $CLUSTER_NAME_PREFIX-controller) ps
}

info_node(){
    log "Inspecting Node: compute-$1"
    
    if [[ -n $2 ]]; then
        format="-f $2"
    fi
    
    cmd="docker $(docker-machine config $CLUSTER_NAME_PREFIX-compute-$1) inspect $format compute-$1"
    $cmd
}

start_net(){
    log "Enable network adapter of node: compute-$1"
    
    docker $(docker-machine config $CLUSTER_NAME_PREFIX-compute-"$1") network connect hadoop-net compute-$1
}

stop_net(){
    log "Disable network adapter of node: compute-$1"
    
    docker $(docker-machine config $CLUSTER_NAME_PREFIX-compute-"$1") network disconnect hadoop-net compute-$1
}

hadoop_cmd(){
    log "Using hadoop console command: $@"
    
    docker $(docker-machine config $CLUSTER_NAME_PREFIX-controller) exec controller "$@"
}

console(){
    log "Enter console connected to the cluster"
    
    do_clustersh "console"
}

hdfs_download(){
    log "Downloading file from HDFS: $@"
    
    do_clustersh "hdfs-download $@"
}

shell_init(){
    do_clustersh "shell-init"
}

connection_info(){
    do_clustersh "connect-info"
}

start(){
    log "Starting cluster+hadoop"
    
    start_cluster && start_hadoop
}

stop(){
    log "Stopping hadoop+cluster"
    
    stop_hadoop
    stop_cluster
}

restart(){
    log "Restarting hadoop+cluster"
    
    stop && start
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
        restart)
            if [[ -z "$machine" ]]
            then
                restart_cluster
            else
                restart_machine $machine
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
    format="$3"
    
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
        restart)
            if [[ -z "$node" ]]
            then
                restart_hadoop
            else
                restart_node $node
            fi
            ;;
        destroy)
            destroy_hadoop
            ;;
        info)
            if [[ -z "$node" ]]
            then
                ls_hadoop
            else
                info_node $node "$format"
            fi
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

print_help(){
cat << EOM
Usage: $0 [OPTIONS] COMMAND

Options:
    -c, --config            Use the given config
    -f, --force             Use '-f' in docker commands where applicable
    -h, --help              Prints this help
    -q, --quiet             Do not print which commands are executed

General Cluster+Hadoop commands:
    start                   starting cluster+hadoop
    stop                    stopping hadoop+cluster
    restart                 restarts cluster+hadoop
    
Cluster commands:
    cluster start [node-id] starting cluster or the given machine
    cluster stop [node-id]  stopping hadoop or the given machine
    cluster restart [node]  restarts hadoop or the given machine
    cluster destroy         destroys the cluster
    
Hadoop container commands:
    hadoop start [node-id]  starting hadoop or the given node
    hadoop stop [node-id]   stopping hadoop or the given node
    hadoop restart [node]   restarts hadoop or the given node
    hadoop destroy          destroys hadoop
    hadoop info [id] [form] list running containers or node container details
                              and can use --format string
    
Hadoop container network commands:
    net start <node-id>     enables networking interfaces on the given node
    net stop <node-id>      disables networking interfaces on the given node
  
Misc commands:
    cmd <cmd>               executes the given command on hadoop controller
    
    console                 starts a console container connected to the cluster
    hdfsdl <file>           download the file from HDFS to current directory
    shinit                  shows info to init the current shell to the cluster
                              usefull as 'eval \$($0 shell-init)'
    conninfo                shows connection infos to the cluster
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
        restart)
            command=restart
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
        cmd)
            command=hadoop_cmd
            break
            ;;
        console)
            command=console
            break
            ;;
        hdfsdl)
            command=hdfs_download
            break
            ;;
        shinit)
            command=shell_init
            break
            ;;
        conninfo)
            command=connection_info
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
