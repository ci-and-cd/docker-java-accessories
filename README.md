# docker-java-accessories

Java accessories (agent, profiler) for multi-stage docker image build.

Dockerfile [ci-and-cd/docker-java-accessories on Github](https://github.com/ci-and-cd/docker-java-accessories)

[cirepo/java-accessories on Docker Hub](https://hub.docker.com/r/cirepo/java-accessories/)


Auto build at [travis-ci](https://travis-ci.org/ci-and-cd/docker-java-accessories)

## Use this image as a “stage” in multi-stage builds

```dockerfile

FROM alpine:3.8

# jprofiler agent need libstdc++.so.6 in libstdc++
# Could not find agent library /opt/jprofiler/bin/linux-x64/libjprofilerti.so in absolute path, with error: libstdc++.so.6: cannot open shared object file: No such file or directory
COPY --from=cirepo/java-accessories:latest-archive /data/root /

```
