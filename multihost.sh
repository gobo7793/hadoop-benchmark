#!/bin/bash

DIR=~/hadoop-benchmark
TERM=xterm
export TERM
CONFIG=masterthesis
export CONFIG
CLUSTERSH="$DIR/cluster.sh"

cd "$DIR"

[[ -f $CONFIG ]] && source $CONFIG

declare -r docker_name_prefix="$CONTAINER_NAME_PREFIX"
declare -r network_name='hadoop-net'
declare -r script_name="$(basename $0)"
declare -r consul_container_name="$docker_name_prefix-consul"
declare -r graphite_container_name="$docker_name_prefix-graphite"
declare -r controller_container_name="$docker_name_prefix-controller"
declare -r compute_container_name="$docker_name_prefix-compute"

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

unknown_command(){
    error "$@: unknown command or argument"
    print_help
}

run_container(){
    name=$1
    shift
    options="$@"
    
    #from https://stackoverflow.com/a/38576401
    if [[ ! "$(docker ps -q -f name=$name)" ]]; then
        if [[ "$(docker ps -aq -f status=exited -f name=$name)" ]]; then
            log "Container $name exists, removing"
            docker rm $name
        fi
        log "Run container: $name"
        docker run --name $name $options
    fi
}

stop_container(){
    name=$1
    
    log "Stop container $name"
    docker stop $name
}

create_net(){    
    log "Creating docker overlay network: $network_name"    
    docker network create -d overlay --attachable $network_name
}

destroy_net(){    
    log "Destroy docker overlay network: $network_name"    
    docker network rm -d overlay --attachable $network_name
}

start_net(){
    node="$compute_container_name-$1"
    
    log "Enable network adapter on node: $node"    
    docker network connect $network_name "$node"
}

stop_net(){
    node="$compute_container_name-$1"
    
    log "Disable network adapter on node: $node"    
    docker network disconnect $network_name "$node"
}

hadoop_cmd(){
    log "Using hadoop console command: $@"
    
    docker exec $controller_container_name "$@"
}

get_controller_ip(){
    docker inspect \
        -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
        $controller_container_name
}

start_consul(){
    run_container $consul_container_name \
        -d \
        -p 8500:8500 \
        -h consul \
        progrium/consul \
        -server \
        -bootstrap
}

stop_consul(){
    stop_container $consul_container_name
}

start_graphite(){
    run_container $graphite_container_name \
        -d \
        -h graphite \
        --restart=always \
        --net $network_name \
        -p 80:80 \
        -p 2003:2003 \
        -p 8125:8125/udp \
        -p 8126:8126 \
        hopsoft/graphite-statsd
}

stop_graphite(){
    stop_container $graphite_container_name
}

start_controller(){
    run_container $controller_container_name \
        -h controller \
        --net $network_name \
        -p 8088:8088 \
        -p 8188:8188 \
        -p 19888:19888 \
        -p 50070:50070 \
        -e CONF_CONTROLLER_HOSTNAME=controller \
        -d \
        $HADOOP_IMAGE \
        controller
}

stop_controller(){
    stop_container $controller_container_name
}

start_compute(){
    name="compute-$1"
    controllerip=$2
    
    http_port=$((8041+$1))
    hdfs_port=$((50074+$1))
    
    run_container "$compute_container_name-$1" \
        -h $name \
        --net $network_name \
        --add-host="controller:$controllerip" \
        -p "$http_port:8042" \
        -p "$hdfs_port:50075" \
        -e "CONF_CONTROLLER_HOSTNAME=controller" \
        -d \
        $HADOOP_IMAGE \
        compute
}

stop_compute(){
    stop_container "$compute_container_name-$1"
}

start(){
    type=$1
    computeid=$2
    controllerip=$3
    
    case "$type" in
        graphite)
            start_graphite
            ;;
        controller)
            start_controller
            ;;
        compute)
            start_compute $computeid $controllerip
            ;;
        *)
            unknown_command "start $type"
            ;;
    esac
}

stop(){
    type=$1
    computeid=$2
    
    case "$type" in
        graphite)
            stop_graphite
            ;;
        controller)
            stop_controller
            ;;
        compute)
            stop_compute $computeid
            ;;
        *)
            unknown_command "stop $type"
            ;;
    esac
}

net(){
    cmd=$1
    node=$2
    
    case "$cmd" in
        start)
            start_net $node
            ;;
        stop)
            stop_net $node
            ;;
        create)
            create_net $node
            ;;
        destroy)
            destroy_net $node
            ;;
        *)
            unknown_command "net $cmd"
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

Start container commands:
    start graphite          Starting graphite container
    start controller        Starting controller container
    start compute <id> <controllerip>
                            Starting given compute container

Stopping container commands:
    stop graphite           Stopping graphite container
    stop controller         Stopping controller container
    stop compute <id>       Stopping given compute container

Hadoop container network commands:
    net start <node-id>     Enables networking interfaces on the given node
    net stop <node-id>      Disables networking interfaces on the given node
    
    net create              Creates the docker overlay network
    net destroy             Destroys the docker overlay network

Misc commands:
    cmd <cmd>               Executes the given command on hadoop controller
    controllerip            Gets the controller ip based on hadoop network

Notes:
    Only for the local docker container on this host of the multihost cluster.
    Starts NUM_COMPUTE_NODES compute nodes on controller host and the half count
    on worker host, so 1.5*NUM_COMPUTE_NODES compute nodes will be created.

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
        net)
            command=net
            break
            ;;
        cmd)
            command=hadoop_cmd
            break
            ;;
        controllerip)
            command=get_controller_ip
            break
            ;;
        *)
            error "$1: unknown command or argument"
            command=print_help
            ;;
    esac
done

shift

$command "$@"
