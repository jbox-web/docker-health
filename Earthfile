VERSION 0.7

all-binaries:
  BUILD \
    --platform=linux/amd64 \
    --platform=linux/arm64 \
    +build-binary

all-docker-images:
  BUILD \
    --platform=linux/amd64 \
    --platform=linux/arm64 \
    +build-docker

build-binary:
  FROM DOCKERFILE --target binary-file .
  SAVE ARTIFACT /build/bin/docker-health-* AS LOCAL packages/

build-docker:
  FROM DOCKERFILE --target docker-image .
  SAVE IMAGE docker-health-dev-multi:latest
