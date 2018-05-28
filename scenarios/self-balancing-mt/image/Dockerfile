FROM hadoop-benchmark/self-balancing-example
LABEL maintainer="gerald.siegert@student.uni-augsburg.de"

ADD hadoop-conf/* /usr/local/hadoop/etc/hadoop/

ADD before-start.sh /
ADD after-start.sh /
ADD before-stop.sh /

ENTRYPOINT [ "/entrypoint.sh" ]

# Timeline ports
EXPOSE 10200 8188 8190
