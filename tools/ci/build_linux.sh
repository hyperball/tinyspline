#!/bin/bash
set -e

SCRIPT_DIR=$( cd $(dirname $0); pwd -P)
ROOT_DIR="${SCRIPT_DIR}/../.."
DIST_DIR="${SCRIPT_DIR}/dist"
mkdir -p ${DIST_DIR}

# Docker image repository.
REPOSITORY="tinyspline"

STRETCH_SETUP_CMDS=$(cat << END
RUN apt-get update && apt-get install -y --no-install-recommends cmake swig
COPY . /tinyspline
WORKDIR /tinyspline
END
)

# Expects that the artifacts are located at /tinyspline/dist/
COPY_ARTIFACTS_AND_DELETE() {
	CONTAINER_ID=$(docker ps -aqf "name=${1}")
	docker cp "${CONTAINER_ID}":/tinyspline/dist/. ${DIST_DIR}
	docker rm "${CONTAINER_ID}"
	docker rmi "${REPOSITORY}:${1}"
}

################################# C#, D, Java #################################
NAME="misc"
docker build -t "${REPOSITORY}:${NAME}" -f - ${ROOT_DIR} <<-END
	FROM buildpack-deps:stretch
	${STRETCH_SETUP_CMDS}
	RUN apt-get install -y --no-install-recommends 	\
		mono-mcs nuget \
		dub \
		default-jdk maven
	END
docker run --name "${NAME}" "${REPOSITORY}:${NAME}" \
	/bin/bash -c "mkdir -p dist && cmake \
	-DTINYSPLINE_ENABLE_CSHARP=True \
	-DTINYSPLINE_ENABLE_DLANG=True \
	-DTINYSPLINE_ENABLE_JAVA=True . && \
	cmake --build . --target tinysplinecsharp && \
		nuget pack && mv ./*.nupkg dist/ && \
	dub build && tar cJf dist/tinysplinedlang.linux-x86_64.tar.xz dub && \
	mvn package && mv ./target/*.jar dist/"
	COPY_ARTIFACTS_AND_DELETE ${NAME}

################################### Python ####################################
BUILD_PYTHON() {
	NAME="python${1}"
	docker build -t "${REPOSITORY}:${NAME}" -f - ${ROOT_DIR} <<-END
		FROM python:${1}-stretch
		${STRETCH_SETUP_CMDS}
		END
	docker run --name "${NAME}" "${REPOSITORY}:${NAME}" \
		/bin/bash -c "cmake -DTINYSPLINE_ENABLE_PYTHON=True . && \
		python setup.py bdist_wheel"
	COPY_ARTIFACTS_AND_DELETE ${NAME}
}

BUILD_PYTHON 2.7
BUILD_PYTHON 3.5
BUILD_PYTHON 3.6
BUILD_PYTHON 3.7
