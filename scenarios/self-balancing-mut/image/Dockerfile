FROM hadoop-benchmark/self-balancing-mt
LABEL maintainer="gerald.siegert@student.uni-augsburg.de"

ADD self-balancing /self-balancing
ADD after-start.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
