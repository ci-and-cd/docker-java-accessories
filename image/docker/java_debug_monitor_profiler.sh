#!/usr/bin/env bash

# see: https://linuxconfig.org/how-to-retrieve-docker-container-s-internal-ip-address
if [[ ! -z "${EUREKA_INSTANCE_HOSTNAME}" ]]; then
    JAVA_RMI_SERVER_HOSTNAME="${EUREKA_INSTANCE_HOSTNAME}"
else
    ip_addr=$(ip addr show eth0 | grep -Po 'inet \K[\d.]+')
    JAVA_RMI_SERVER_HOSTNAME="${ip_addr}"
fi
(>&2 echo "java.rmi.server.hostname: ${JAVA_RMI_SERVER_HOSTNAME}")

if [[ ! -z "${JAVA_DEBUG_PORT}" ]]; then
    # For running remote JVM
    #JAVA_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=${JAVA_DEBUG_PORT} ${JAVA_OPTS}";
    # For JDK 1.4.x +
    JAVA_OPTS="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=${JAVA_DEBUG_PORT} ${JAVA_OPTS}";
    (>&2 echo "Java remote debug enabled, at '${JAVA_RMI_SERVER_HOSTNAME}:${JAVA_DEBUG_PORT}'")
fi

# see: https://www.jamasoftware.com/blog/monitoring-java-applications/
# see: https://docs.oracle.com/javase/8/docs/technotes/guides/management/agent.html
# see: https://github.com/anthony-o/ejstatd
if [[ ! -z "${JAVA_JMX_PORT}" ]]; then
    if [[ "${JAVA_JMC_ENABLED}" = "true" ]]; then
        JAVA_OPTS="${JAVA_OPTS} -XX:+UnlockCommercialFeatures -XX:+FlightRecorder"
        (>&2 echo "Java JMC enabled, at '${JAVA_RMI_SERVER_HOSTNAME}:${JAVA_JMX_PORT}'")
    fi
    JAVA_OPTS="${JAVA_OPTS} -Djava.rmi.server.hostname=${JAVA_RMI_SERVER_HOSTNAME}"
    JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.rmi.port=${JAVA_JMX_PORT}"
    JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.port=${JAVA_JMX_PORT}"
    JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote=true"
    JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.local.only=false"
    JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.ssl=false"
    if [[ ! -z "${SPRING_SECURITY_USER_NAME}" ]] && [[ ! -z "${SPRING_SECURITY_USER_PASSWORD}" ]]; then
        echo "${SPRING_SECURITY_USER_NAME} ${SPRING_SECURITY_USER_PASSWORD}" > /tmp/password.properties
        echo "${SPRING_SECURITY_USER_NAME} readwrite \\" > /tmp/access.properties
        echo "  create com.sun.management.*,com.oracle.jrockit.* \\" >> /tmp/access.properties
        echo "  unregister" >> /tmp/access.properties
        chmod 600 /tmp/password.properties /tmp/access.properties
        JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.authenticate=true"
        JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.password.file=/tmp/password.properties"
        JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.access.file=/tmp/access.properties"
    else
        JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.authenticate=false"
    fi
    (>&2 echo "Java JMX management enabled, at '${JAVA_RMI_SERVER_HOSTNAME}:${JAVA_JMX_PORT}'")
fi

# ejstatd, see: https://github.com/anthony-o/ejstatd
if [[ ! -z "${JAVA_JSTATD_RMI_PORT}" ]] && [[ ! -z "${JAVA_JSTATD_RH_PORT}" ]] && [[ ! -z "${JAVA_JSTATD_RV_PORT}" ]]; then
    java -Djava.rmi.server.hostname=${JAVA_RMI_SERVER_HOSTNAME} \
        -cp "/opt/ejstatd/ejstatd-1.0.0.jar:${JAVA_HOME}/lib/tools.jar" \
        com.github.anthony_o.ejstatd.EJstatd \
        -pr${JAVA_JSTATD_RMI_PORT} \
        -ph${JAVA_JSTATD_RH_PORT} \
        -pv${JAVA_JSTATD_RV_PORT} &
    (>&2 echo "Java jstatd enabled, at '${JAVA_RMI_SERVER_HOSTNAME}:${JAVA_JSTATD_RMI_PORT} ${JAVA_JSTATD_RH_PORT} ${JAVA_JSTATD_RV_PORT}'")
fi

# JProfiler agent, see: http://resources.ej-technologies.com/jprofiler/help/doc/sessions/remoteTable.html
# find config.xml at client side ~/.jprofiler10/config.xml
if [[ ! -z "${JAVA_JPROFILER_PORT}" ]] && [[ ! -z "${JAVA_JPROFILER_CONFIG}" ]]; then
    JAVA_OPTS="-agentpath:/opt/jprofiler/bin/linux-x64/libjprofilerti.so=port=${JAVA_JPROFILER_PORT},nowait,config=${JAVA_JPROFILER_CONFIG} ${JAVA_OPTS}"
    (>&2 echo "Java JProfiler enabled, at '${JAVA_RMI_SERVER_HOSTNAME}:${JAVA_JPROFILER_PORT}'")
fi

# YourKit doc, see: https://www.yourkit.com/docs/
# YourKit agent, see: https://helpx.adobe.com/experience-manager/kb/HowToConfigureYourKitJavaProfiler.html

# https://medium.com/netflix-techblog/java-in-flames-e763b3d32166
if [[ "${PRESERVE_FRAME_POINTER}" == "true" ]]; then
    JAVA_OPTS="${JAVA_OPTS} -XX:+PreserveFramePointer -XX:InlineSmallCode=500";
fi
