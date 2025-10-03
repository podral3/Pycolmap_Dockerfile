import pycolmap
from pathlib import Path

# Create database path
db_path = Path("database.db")
db_path.parent.mkdir(parents=True, exist_ok=True)

# Create COLMAP database
db = pycolmap.Database()
database = db.open(str(db_path))

print(f"Database created at: {db_path}")

# Extract features from images
image_dir = Path("images")
if image_dir.exists():
    pycolmap.extract_features(database_path=str(db_path),
                               image_path=str(image_dir),
                                 )
    pycolmap.match_exhaustive(str(db_path))
    maps = pycolmap.incremental_mapping(str(db_path), 
                                        image_path= str(image_dir),
                                        output_path="output")
    database.close()
    maps[0].export_PLY("sparse_model.ply")
    print("Success!")
else:
    print(f"Image directory not found: {image_dir}")