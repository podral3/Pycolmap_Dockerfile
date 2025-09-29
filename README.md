# PyCOLMAP Docker Workspace

This workspace provides scripts and a Docker setup for building and running [PyCOLMAP](https://github.com/colmap/pycolmap) with CUDA support.

## Quick Start

### 1. Run scripts in this order

```sh
chmod +x setup-pycolmap.sh
chmod +x build-pycolmap.sh
chmod +x run-pycolmap.sh
```
### 2. Test
test inside container using test_pycolmap.py

## Uwagi
### Pierwszy skrypt może nie znaleźc pasującego obrazu, w takim wypadku pominąć i odpalić 2
### User może nie być w grupie docker przez co 2 skrypt nie zadziała należy dodać użytkownika do grupy docker lub odpalić z roota

```sh
sudo usermod -aG docker $USER
```

### Na starszych wersjach cudy oraz ubuntu biblioteki lub wersja pythona mogą być niekompatybilne