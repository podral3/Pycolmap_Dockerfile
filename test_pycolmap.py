#!/usr/bin/env python3
"""
Test script to verify PyCOLMAP installation and CUDA support.
Run this inside the Docker container to verify everything works.
"""

import sys

def test_imports():
    """Test that all required packages can be imported."""
    print("🔍 Testing imports...")
    
    try:
        import pycolmap
        print(f"✅ pycolmap version: {pycolmap.__version__}")
    except ImportError as e:
        print(f"❌ Failed to import pycolmap: {e}")
        return False
    
    try:
        import numpy as np
        print(f"✅ numpy version: {np.__version__}")
    except ImportError as e:
        print(f"❌ Failed to import numpy: {e}")
        return False
    
    try:
        import PIL
        print(f"✅ PIL version: {PIL.__version__}")
    except ImportError as e:
        print(f"❌ Failed to import PIL: {e}")
        return False
    
    return True

def test_cuda():
    """Test CUDA availability."""
    print("\n🔍 Testing CUDA support...")
    
    try:
        import pycolmap
        if pycolmap.has_cuda:
            print("✅ CUDA is available in PyCOLMAP")
            return True
        else:
            print("⚠️  CUDA is not available in PyCOLMAP")
            return False
    except Exception as e:
        print(f"❌ Error checking CUDA: {e}")
        return False

def test_basic_functionality():
    """Test basic PyCOLMAP functionality."""
    print("\n🔍 Testing basic PyCOLMAP functionality...")
    
    try:
        import pycolmap
        import numpy as np
        
        # Create a simple camera
        camera = pycolmap.Camera(
            model="SIMPLE_PINHOLE",
            width=640,
            height=480,
            params=[500.0, 320.0, 240.0]
        )
        print(f"✅ Created camera: {camera.model}")
        
        # Create a simple image
        image = pycolmap.Image(
            id=1,
            name="test.jpg",
            camera_id=1,
            qvec=np.array([1.0, 0.0, 0.0, 0.0]),
            tvec=np.array([0.0, 0.0, 0.0])
        )
        print(f"✅ Created image: {image.name}")
        
        # Create a reconstruction
        reconstruction = pycolmap.Reconstruction()
        print("✅ Created reconstruction object")
        
        return True
    except Exception as e:
        print(f"❌ Error testing functionality: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests."""
    print("=" * 60)
    print("PyCOLMAP Installation Test")
    print("=" * 60)
    
    tests_passed = 0
    tests_total = 3
    
    if test_imports():
        tests_passed += 1
    
    if test_cuda():
        tests_passed += 1
    
    if test_basic_functionality():
        tests_passed += 1
    
    print("\n" + "=" * 60)
    print(f"Results: {tests_passed}/{tests_total} tests passed")
    print("=" * 60)
    
    if tests_passed == tests_total:
        print("✅ All tests passed! PyCOLMAP is ready to use.")
        return 0
    else:
        print("⚠️  Some tests failed. Check the output above for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())