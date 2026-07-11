# Ascend CANN server Docker 镜像构建

本文档说明如何在本地构建适用于 Ascend CANN 后端的 `llama-server` Docker 镜像。

相关 Dockerfile 位于 `.devops` 目录：

- `.devops/llama-server-cann-910b.Dockerfile`
- `.devops/llama-server-cann-910c.Dockerfile`

这些 Dockerfile 基于 Ascend CANN toolkit 镜像构建，并在编译阶段使用 toolkit 内置的 stub runtime library。因此，构建镜像时不需要本机安装昇腾显卡。实际运行推理时，才需要具备昇腾设备、驱动以及对应的容器运行时配置。

下面的命令显式指定 `linux/arm64` 平台，因为昇腾显卡部署环境通常使用 arm64 平台。

## 构建 910B 镜像

```bash
DOCKER_BUILDKIT=1 docker build \
  --platform linux/arm64 \
  --target server \
  -f .devops/llama-server-cann-910b.Dockerfile \
  -t ghcr.io/ggml-org/llama.cpp:server-cann-910b \
  .
```

## 构建 910C 镜像

```bash
DOCKER_BUILDKIT=1 docker build \
  --platform linux/arm64 \
  --target server \
  -f .devops/llama-server-cann-910c.Dockerfile \
  -t ghcr.io/ggml-org/llama.cpp:server-cann-910c \
  .
```

## 在 x86 主机上构建

在 x86 主机上构建上述 arm64 镜像通常也是可行的，前提是 Docker 已经配置好 arm64 binfmt/QEMU 仿真。Docker Desktop 通常已经内置相关支持。

如果在 Linux 主机上构建时遇到架构或 `exec format error` 相关错误，可以先安装 arm64 仿真支持：

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64
```

跨架构构建会比原生 arm64 构建更慢。

## 可选构建元数据

Dockerfile 还支持传入和 CI 工作流一致的镜像元数据参数：

```bash
DOCKER_BUILDKIT=1 docker build \
  --platform linux/arm64 \
  --target server \
  -f .devops/llama-server-cann-910b.Dockerfile \
  -t ghcr.io/ggml-org/llama.cpp:server-cann-910b \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg APP_VERSION="$(git describe --tags --always --dirty)" \
  --build-arg APP_REVISION="$(git rev-parse HEAD)" \
  .
```
