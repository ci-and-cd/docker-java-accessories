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


# https://medium.com/netflix-techblog/java-in-flames-e763b3d32166
if [[ "${JAVA_PRESERVE_FRAME_POINTER}" == "true" ]]; then
    JAVA_OPTS="${JAVA_OPTS} -XX:+PreserveFramePointer -XX:InlineSmallCode=500 -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints";
fi


# JProfiler agent, see: http://resources.ej-technologies.com/jprofiler/help/doc/sessions/remoteTable.html
# find config.xml at client side ~/.jprofiler10/config.xml
if [[ ! -z "${JAVA_JPROFILER_CONFIG}" ]] && [[ ! -z "${JAVA_JPROFILER_SESSION_ID}" ]]; then
    JAVA_JPROFILER_AGENT="-agentpath:${JAVA_JPROFILER_PATH:-/opt/jprofiler}/bin/linux-x64/libjprofilerti.so="
    if [[ -n "${JAVA_JPROFILER_PORT}" ]]; then
        JAVA_JPROFILER_AGENT="${JAVA_JPROFILER_AGENT}port=${JAVA_JPROFILER_PORT},nowait"
    else
        JAVA_JPROFILER_AGENT="${JAVA_JPROFILER_AGENT}offline"
    fi
    JAVA_JPROFILER_AGENT="${JAVA_JPROFILER_AGENT},id=${JAVA_JPROFILER_SESSION_ID}"
    JAVA_JPROFILER_AGENT="${JAVA_JPROFILER_AGENT},config=${JAVA_JPROFILER_CONFIG}"
    JAVA_OPTS="${JAVA_JPROFILER_AGENT} ${JAVA_OPTS}"
    (>&2 echo "Java JProfiler enabled, agent '${JAVA_JPROFILER_AGENT}'")
fi


# ejstatd, see: https://github.com/anthony-o/ejstatd
# Caused by: java.security.AccessControlException: access denied ("java.util.PropertyPermission" "sun.jvmstat.monitor.local" "read")
if [[ ! -z "${JAVA_JSTATD_RMI_PORT}" ]] && [[ ! -z "${JAVA_JSTATD_RH_PORT}" ]] && [[ ! -z "${JAVA_JSTATD_RV_PORT}" ]]; then
    # see: https://stackoverflow.com/questions/51032095/starting-jstatd-in-java-9
    JAVA_JSTATD_JAR="ejstatd-1.0.0.jar"
    if (( $(echo "${JAVA_VERSION} > 10.0" | bc -l) )); then
        JAVA_JSTATD_JAR="ejstatd-1.0.0-java11.jar"
        # Java11's default policy file: -Djava.security.policy=${JAVA_HOME}/conf/security/java.policy
        #JAVA_SECURITY_POLICY="/opt/ejstatd/java11-jstatd.all.policy"
    elif [[ "${JAVA_VERSION}" == "10.0" ]]; then
        JAVA_JSTATD_JAR="ejstatd-1.0.0-java10.jar"
        #JAVA_SECURITY_POLICY="/opt/ejstatd/java10-jstatd.all.policy"
    elif [[ "${JAVA_VERSION}" == "9.0" ]]; then
        JAVA_JSTATD_JAR="ejstatd-1.0.0-java9.jar"
        #JAVA_SECURITY_POLICY="/opt/ejstatd/java9-jstatd.all.policy"
    elif [[ "${JAVA_VERSION}" == "1.8" ]]; then
        JAVA_JSTATD_JAR="ejstatd-1.0.0-java8.jar"
        #JAVA_SECURITY_POLICY="/opt/ejstatd/java8-jstatd.all.policy"
    else
        (>&2 echo "Unsupported java version ${JAVA_VERSION}")
    fi

    if (( $(echo "${JAVA_VERSION} > 8.0" | bc -l) )); then
        java --add-modules jdk.jstatd,jdk.internal.jvmstat \
            -Djava.rmi.server.hostname=${JAVA_RMI_SERVER_HOSTNAME} \
            -cp "/opt/ejstatd/${JAVA_JSTATD_JAR}" \
            com.github.anthony_o.ejstatd.EJstatd \
            -pr${JAVA_JSTATD_RMI_PORT} \
            -ph${JAVA_JSTATD_RH_PORT} \
            -pv${JAVA_JSTATD_RV_PORT} &
    else
        java \
            -Djava.rmi.server.hostname=${JAVA_RMI_SERVER_HOSTNAME} \
            -cp "/opt/ejstatd/${JAVA_JSTATD_JAR}:${JAVA_HOME}/lib/tools.jar" \
            com.github.anthony_o.ejstatd.EJstatd \
            -pr${JAVA_JSTATD_RMI_PORT} \
            -ph${JAVA_JSTATD_RH_PORT} \
            -pv${JAVA_JSTATD_RV_PORT} &
    fi

    (>&2 echo "Java jstatd enabled, at '${JAVA_RMI_SERVER_HOSTNAME}:${JAVA_JSTATD_RMI_PORT} ${JAVA_JSTATD_RH_PORT} ${JAVA_JSTATD_RV_PORT}'")
fi


# YourKit doc, see: https://www.yourkit.com/docs/
# YourKit agent, see: https://helpx.adobe.com/experience-manager/kb/HowToConfigureYourKitJavaProfiler.html
