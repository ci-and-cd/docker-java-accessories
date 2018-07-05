
FROM alpine:3.7


COPY --chown=root:root docker /data


RUN set -ex \
  && mkdir -p /opt/ejstatd \
  && mv /data/ejstatd-1.0.0.jar /opt/ejstatd/ejstatd-1.0.0.jar \
  && mv /data/java_debug_monitor_profiler.sh /opt/java_debug_monitor_profiler.sh \
  && mkdir -p /opt/jprofiler/bin/linux-x64 \
  && mv /data/jprofiler/bin/linux-x64/libattach.so /opt/jprofiler/bin/linux-x64/libattach.so \
  && mv /data/jprofiler/bin/linux-x64/libjprofilerti.so /opt/jprofiler/bin/linux-x64/libjprofilerti.so
# Need libstdc++.so.6 in libstdc++
# Could not find agent library /opt/jprofiler/bin/linux-x64/libjprofilerti.so in absolute path, with error: libstdc++.so.6: cannot open shared object file: No such file or directory
