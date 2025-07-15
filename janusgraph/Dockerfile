# janusgraph/Dockerfile 

FROM janusgraph/janusgraph:1.1.0

USER root

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]