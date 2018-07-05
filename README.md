# docker-java-accessories

Java accessories (agent, profiler) for multi-stage docker image build.

Dockerfile [ci-and-cd/docker-java-accessories on Github](https://github.com/ci-and-cd/docker-java-accessories)

[cirepo/java-accessories on Docker Hub](https://hub.docker.com/r/cirepo/java-accessories/)

## Use this image as a “stage” in multi-stage builds

```dockerfile

FROM alpine:3.7

COPY --from=cirepo/java-accessories:latest-archive /data/root /

```
