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

check_docker_container() {
  name=$1

  docker inspect -f '{{.State.Status}}' $name 2> /dev/null || echo 'nonexistent'
}

build_container(){
    name=$1
    shift
    options="$@"
    
    log "Checking status of docker image: $name:latest"
    if [[ ! docker inspect $name:latest > /dev/null 2>&1 ]]; then
        log "Docker image $name:latest does not exist, creating..."
        docker build -t $name $options
    else
        log "Docker image $name:latest exists"
    fi
}

run_container(){
    name=$1
    shift
    options="$@"

    log "Checking status of docker container: $name"
    status=$(check_docker_container $name)
    
    # from https://stackoverflow.com/a/38576401 and modyfied
    if [[ $status -eq "running" ]]; then
        log "Container $name already running"
    else
        if [[ $status -eq "exited" ]]; then
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

build_hadoop(){
    build_container $HADOOP_IMAGE $HADOOP_IMAGE_DIR
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
        
    log "Controller IP: $(get_controller_ip)"
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

start_host(){
    hostid=$1
    controllerip=$2
    computeid=1
    computesPerHost=$(($NUM_COMPUTE_NODES/2))
    
    log "Start host $1"
    
    # start host 1 with controller
    if [[ $hostid -eq 1 ]]; then
        start_graphite
        start_controller
        controllerip=$(get_controller_ip)
        for i in $(seq 1 $computesPerHost); do
            start_compute $computeid $controllerip
            ((++computeid))
        done
    fi
    
    # start other hosts
    computeid=$(($computesPerHost*$hostid+1))
    for i in $(seq 1 $computesPerHost); do
        start_compute $computeid $controllerip
        ((++computeid))
    done
}

stop_host(){
    hostid=$1
    computeid=1
    computesPerHost=$(($NUM_COMPUTE_NODES/2))
    
    # stop other hosts
    computeid=$(($computesPerHost*$hostid+1))
    for i in $(seq 1 $computesPerHost); do
        stop_compute $computeid
        ((++computeid))
    done
    
    # stop host 1 with controller
    if [[ $hostid -eq 1 ]]; then
        computeid=1
        for i in $(seq 1 $computesPerHost); do
            stop_compute $computeid $controllerip
            ((++computeid))
        done
        stop_controller
        stop_graphite
    fi
}

start(){
    type=$1
    id=$2
    controllerip=$3
    
    case "$type" in
        host)
            start_host $id $controllerip
            ;;
        graphite)
            start_graphite
            ;;
        controller)
            start_controller
            ;;
        compute)
            start_compute $id $controllerip
            ;;
        *)
            unknown_command "start $type"
            ;;
    esac
}

build(){
    type=$1
    
    case "$type" in
        hadoop)
            build_controller
            ;;
        *)
            unknown_command "build $type"
            ;;
    esac
}

stop(){
    type=$1
    id=$2
    
    case "$type" in
        host)
            stop_host $id
            ;;
        graphite)
            stop_graphite
            ;;
        controller)
            stop_controller
            ;;
        compute)
            stop_compute $id
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

Build image commands:
    build hadoop            Builds hadoop container image

Start container commands:
    start host <number> [controllerip]
                            Starts all container on host <number>.
                            Controller ip needed for other hosts than 1.
                            Containers doesn't exists will be builded.

    start graphite          Starts graphite container
    start controller        Starts controller container
    start compute <id> <controllerip>
                            Starts given compute container

Stopping container commands:
    stop host <number>      Stops all container on host <number>.

    stop graphite           Stops graphite container
    stop controller         Stops controller container
    stop compute <id>       Stops given compute container

Hadoop container network commands:
    net start <node-id>     Enables networking interfaces on the given node
    net stop <node-id>      Disables networking interfaces on the given node
    
    net create              Creates the docker overlay network
    net destroy             Destroys the docker overlay network

Misc commands:
    cmd <cmd>               Executes the given command on hadoop controller
    controllerip            Gets the controller ip based on hadoop network

Notes:
    Only for the local docker container on localhost of the multihost cluster.
    Starts NUM_COMPUTE_NODES compute nodes on host 1 and the half count on other
    hosts >1, so (1+hosts/2)*NUM_COMPUTE_NODES compute nodes will be created.

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
        build)
            command=build
            break
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
