#!/usr/bin/env python3
"""
YOLOv8 Model Export Script with Correct Parameters
Exports YOLOv8n to TFLite format optimized for Flutter mobile apps
"""

from ultralytics import YOLO
import numpy as np

def export_yolov8_for_flutter():
    """Export YOLOv8n model with correct parameters"""
    
    # Load pre-trained model
    model = YOLO('yolov8n.pt')
    
    # Export to TFLite with specific parameters
    # nms=False is CRITICAL - we do NMS in Dart code
    # imgsz=640 for accuracy
    # int8=False for float32 precision
    path = model.export(
        format='tflite',
        imgsz=640,
        int8=False,
        nms=False,          # CRITICAL: Disable NMS in model, do it in Flutter
        agnostic_nms=False,
        simplify=True,
    )
    
    print(f"✓ Model exported to: {path}")
    print("\nNOTE: Model has NMS disabled - implement NMS in Flutter code")
    return path

def verify_model(model_path):
    """Verify the exported model"""
    import tensorflow as tf
    
    # Load interpreter
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    # Get details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print("\n✓ MODEL VERIFICATION:")
    print(f"  Input shape: {input_details[0]['shape']}")
    print(f"  Input type: {input_details[0]['dtype']}")
    print(f"  Output shape: {output_details[0]['shape']}")
    print(f"  Output type: {output_details[0]['dtype']}")
    
    # Test inference
    dummy_input = np.random.rand(1, 640, 640, 3).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], dummy_input)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    
    print(f"\n✓ TEST INFERENCE:")
    print(f"  Output shape: {output.shape}")
    print(f"  Value range: [{output.min():.4f}, {output.max():.4f}]")
    print(f"  Expected: [1, 84, 8400] with values in [0, 1] range")
    
    # Verify output format
    if output.shape == (1, 84, 8400):
        print("\n✅ Model format is CORRECT for YOLOv8!")
        print("  - 84 = 4 bbox coords + 80 classes")
        print("  - 8400 = number of predictions")
    else:
        print(f"\n⚠️  WARNING: Unexpected output shape: {output.shape}")
        print("  Expected: (1, 84, 8400)")
    
    return True

if __name__ == "__main__":
    print("🚀 Exporting YOLOv8n for Flutter...")
    print("=" * 60)
    
    try:
        model_path = export_yolov8_for_flutter()
        verify_model(model_path)
        
        print("\n" + "=" * 60)
        print("✅ Export complete!")
        print(f"\nNext steps:")
        print(f"  1. Copy {model_path} to assets/models/yolov8n.tflite")
        print(f"  2. Run flutter pub get")
        print(f"  3. Run flutter run")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nTroubleshooting:")
        print("  - Install ultralytics: pip install ultralytics")
        print("  - Download yolov8n.pt: will auto-download on first run")
