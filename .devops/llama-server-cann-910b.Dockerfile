ARG ASCEND_VERSION=9.1.0-beta.3-910b-openeuler24.03-py3.12-devel
ARG BUILD_DATE=N/A
ARG APP_VERSION=N/A
ARG APP_REVISION=N/A

ARG NODE_VERSION=24

FROM docker.io/node:$NODE_VERSION AS web

ARG APP_VERSION

WORKDIR /app/tools/ui

COPY tools/ui/package.json tools/ui/package-lock.json ./
RUN npm ci

COPY tools/ui/ ./
RUN LLAMA_BUILD_NUMBER="$APP_VERSION" npm run build

FROM docker.io/ascendai/cann:${ASCEND_VERSION} AS build

SHELL ["/bin/bash", "-c"]

RUN yum install -y gcc g++ cmake make git openssl-devel && \
    yum clean all && \
    rm -rf /var/cache/yum

ENV ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest
ENV LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${LIBRARY_PATH}
ENV LD_LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${ASCEND_TOOLKIT_HOME}/lib64/plugin/opskernel:${ASCEND_TOOLKIT_HOME}/lib64/plugin/nnengine:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe/op_tiling:${LD_LIBRARY_PATH}
ENV PYTHONPATH=${ASCEND_TOOLKIT_HOME}/python/site-packages:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe:${PYTHONPATH}
ENV PATH=${ASCEND_TOOLKIT_HOME}/bin:${ASCEND_TOOLKIT_HOME}/compiler/ccec_compiler/bin:${PATH}
ENV ASCEND_AICPU_PATH=${ASCEND_TOOLKIT_HOME}
ENV ASCEND_OPP_PATH=${ASCEND_TOOLKIT_HOME}/opp
ENV TOOLCHAIN_HOME=${ASCEND_TOOLKIT_HOME}/toolkit
ENV ASCEND_HOME_PATH=${ASCEND_TOOLKIT_HOME}

# Use stub runtime libraries during image build because host drivers are not mounted.
ENV LD_LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/runtime/lib64/stub:${LD_LIBRARY_PATH}

WORKDIR /app

COPY . .
COPY --from=web /app/tools/ui/dist tools/ui/dist

ARG SOC_TYPE=Ascend910B
RUN source /usr/local/Ascend/ascend-toolkit/set_env.sh --force && \
    cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_NATIVE=OFF \
        -DGGML_CANN=ON \
        -DSOC_TYPE=${SOC_TYPE} \
        -DUSE_ACL_GRAPH=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLAMA_BUILD_TESTS=OFF && \
    cmake --build build --config Release --target llama-server -j$(nproc)

FROM docker.io/ascendai/cann:${ASCEND_VERSION} AS server

ARG BUILD_DATE=N/A
ARG APP_VERSION=N/A
ARG APP_REVISION=N/A
ARG IMAGE_URL=https://github.com/ggml-org/llama.cpp
ARG IMAGE_SOURCE=https://github.com/ggml-org/llama.cpp
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.version=$APP_VERSION \
      org.opencontainers.image.revision=$APP_REVISION \
      org.opencontainers.image.title="llama.cpp" \
      org.opencontainers.image.description="LLM inference in C/C++" \
      org.opencontainers.image.url=$IMAGE_URL \
      org.opencontainers.image.source=$IMAGE_SOURCE

RUN yum install -y curl libgomp && \
    yum clean all && \
    rm -rf /var/cache/yum

COPY --from=build /app/build/bin/llama-server /app/llama-server

ENV LC_ALL=C.utf8
ENV LLAMA_ARG_HOST=0.0.0.0

ENV ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest
ENV LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${LIBRARY_PATH}
ENV LD_LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${ASCEND_TOOLKIT_HOME}/lib64/plugin/opskernel:${ASCEND_TOOLKIT_HOME}/lib64/plugin/nnengine:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe/op_tiling:${LD_LIBRARY_PATH}
ENV PYTHONPATH=${ASCEND_TOOLKIT_HOME}/python/site-packages:${ASCEND_TOOLKIT_HOME}/opp/built-in/op_impl/ai_core/tbe:${PYTHONPATH}
ENV PATH=${ASCEND_TOOLKIT_HOME}/bin:${ASCEND_TOOLKIT_HOME}/compiler/ccec_compiler/bin:${PATH}
ENV ASCEND_AICPU_PATH=${ASCEND_TOOLKIT_HOME}
ENV ASCEND_OPP_PATH=${ASCEND_TOOLKIT_HOME}/opp
ENV TOOLCHAIN_HOME=${ASCEND_TOOLKIT_HOME}/toolkit
ENV ASCEND_HOME_PATH=${ASCEND_TOOLKIT_HOME}

WORKDIR /app

HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]

ENTRYPOINT [ "/app/llama-server" ]
