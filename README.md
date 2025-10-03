# PyCOLMAP Dockerfile

This file extends Dockerfile in orginal COLMAP repository https://github.com/colmap/colmap to have cuda enabled pycolmap.
Use this to run python colmap scripts.

Image avilable at: https://hub.docker.com/r/podral3/pycolmap

Running a simple script

```
docker run --rm \
--name pycolmap \
--gpus all \
-v "/app:/app" \
-w /app podral3/pycolmap:latest \
python3 main.py
```
