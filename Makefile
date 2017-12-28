DOCKER_ARGS=--rm -it -v ${PWD}:${PWD} -w ${PWD}

all: doc

doc:
	docker run ${DOCKER_ARGS} anibali/ldoc .

clean:
	rm -fr doc
