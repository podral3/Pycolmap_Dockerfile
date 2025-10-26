import pycolmap
from pathlib import Path

image_dir = Path("images")
output_path = Path("output")
mvs_path = output_path / "mvs_path"

# Create database path
db_path = output_path / "database.db"
db_path.parent.mkdir(parents=True, exist_ok=True)

# Create COLMAP database
db = pycolmap.Database()
database = db.open(str(db_path))

print(f"Database created at: {db_path}")

# Extract features from images
if image_dir.exists():
    pycolmap.extract_features(database_path=str(db_path),
                               image_path=str(image_dir),
                                 )
    pycolmap.match_exhaustive(str(db_path))
    maps = pycolmap.incremental_mapping(str(db_path), 
                                        image_path= str(image_dir),
                                        output_path="output")
    database.close()
    maps[0].write(output_path)
    maps[0].export_PLY("sparse_model.ply")
    print("Sparse reconstruction finished!")
    pycolmap.undistort_images(mvs_path, output_path, image_dir)
    pycolmap.patch_match_stereo(mvs_path)  # requires compilation with CUDA
    pycolmap.stereo_fusion(mvs_path / "dense.ply", mvs_path)
    print("Dense reconstruction finished")
else:
    print(f"Image directory not found: {image_dir}")