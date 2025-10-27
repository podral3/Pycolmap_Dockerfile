import pycolmap, json

def camera_from_json(path) -> pycolmap.Camera:
    with open(path, "r", encoding="utf-8") as f:
        camera_data = json.load(f)

    return pycolmap.Camera(
        model=camera_data["model"],
        width=camera_data["width"],
        height=camera_data["height"],
        params=camera_data["params"]
    )

def get_imageReaderOptions(camera: pycolmap.Camera, mask_path):
    imageReaderOptions = pycolmap.ImageReaderOptions
    imageReaderOptions.camera_params = camera.params_to_string()
    imageReaderOptions.mask_path = mask_path
    return imageReaderOptions
