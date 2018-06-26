FROM hadoop-benchmark/self-balancing-example
LABEL maintainer="gerald.siegert@student.uni-augsburg.de"

COPY hadoop-conf/* /usr/local/hadoop/etc/hadoop/

COPY before-start.sh /
COPY after-start.sh /
COPY before-stop.sh /

ENTRYPOINT [ "/entrypoint.sh" ]

# Timeline ports
EXPOSE 10200 8188 8190
