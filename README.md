# PyCOLMAP Docker Image

CUDA-enabled PyCOLMAP built on the official [COLMAP repository](https://github.com/colmap/colmap). Run Python COLMAP scripts with GPU acceleration.

**Docker Hub:** https://hub.docker.com/r/podral3/pycolmap

## Quick Start

```bash
docker run --rm \
  --gpus all \
  -v "/app:/app" \
  -w /app \
  podral3/pycolmap:latest \
  python3 main.py
```

## Extending with Dependencies

```dockerfile
FROM podral3/pycolmap:latest
RUN pip install numpy scipy
```
