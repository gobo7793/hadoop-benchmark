FROM spirals/hadoop-benchmark:hadoop-benchmark
MAINTAINER Bo ZHANG <bo.zhang@inria.fr>

# prerequisite
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -yqq && \
    apt-get install -yqq \
		  bc

ADD hadoop-conf/* /usr/local/hadoop/etc/hadoop/
ADD self-balancing /self-balancing
ADD capacity-scheduler.xml /usr/local/hadoop/etc/hadoop/

ADD before-start.sh /
ADD after-start.sh /
ADD before-stop.sh /

WORKDIR /self-balancing

ENTRYPOINT [ "/entrypoint.sh" ]

# Timeline ports
EXPOSE 10200 8188 8190
