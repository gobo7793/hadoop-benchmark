#FROM hadoop-benchmark/hadoop
FROM hadoop-benchmark/self-balancing-mt
MAINTAINER Bo ZHANG <bo.zhang@inria.fr>

# prerequisite
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -yqq && \
    apt-get install -yqq \
		  git \
		  bc \
		  maven \
		  python

ENV HIBENCH_HOME /HiBench

# checkout hibench
RUN git clone https://github.com/intel-hadoop/HiBench.git $HIBENCH_HOME

# set workdirectory
WORKDIR $HIBENCH_HOME

# build hibench
RUN mvn -Phadoopbench -Dspark=2.1 -Dscala=2.11 clean package

# copy configuration files
#ADD hibench-config.sh $HIBENCH_HOME/bin/hibench-config.sh
#ADD HiBench-conf/sleep/configure.sh $HIBENCH_HOME/sleep/conf/
#ADD HiBench-conf/sort/configure.sh $HIBENCH_HOME/sort/conf/
#ADD HiBench-conf/terasort/configure.sh $HIBENCH_HOME/terasort/conf/
#ADD HiBench-conf/wordcount/configure.sh $HIBENCH_HOME/wordcount/conf/
ADD conf/ $HIBENCH_HOME/conf/

# add auxiliary helpers
ADD run.sh /

ENTRYPOINT [ "/entrypoint.sh", "run", "/run.sh" ]
