#!/usr/bin/env python3
"""Check TFLite model input/output shapes and structure"""
import numpy as np

try:
    import tensorflow as tf
    print("✓ TensorFlow found")
except ImportError:
    print("Installing tensorflow...")
    import subprocess
    subprocess.check_call(['pip', 'install', 'tensorflow'])
    import tensorflow as tf

# Load the model
model_path = 'assets/models/yolov5n.tflite'
interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()

# Get input details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("\n" + "="*60)
print("MODEL INSPECTION RESULTS")
print("="*60)

print("\n📥 INPUT TENSOR:")
for i, input_detail in enumerate(input_details):
    print(f"  [{i}] Name: {input_detail['name']}")
    print(f"      Shape: {input_detail['shape']}")
    print(f"      Type: {input_detail['dtype']}")
    
print("\n📤 OUTPUT TENSOR:")
for i, output_detail in enumerate(output_details):
    print(f"  [{i}] Name: {output_detail['name']}")
    print(f"      Shape: {output_detail['shape']}")
    print(f"      Type: {output_detail['dtype']}")

# Calculate expected values
if len(output_details) > 0:
    output_shape = output_details[0]['shape']
    if len(output_shape) == 3:
        batch, anchors, features = output_shape
        # YOLOv5 format: [cx, cy, w, h, objectness, class0, class1, ...]
        num_classes = features - 5
        print(f"\n🔍 ANALYSIS:")
        print(f"  Batch size: {batch}")
        print(f"  Number of anchors: {anchors}")
        print(f"  Features per anchor: {features}")
        print(f"  Calculated classes: {num_classes} (features - 5)")
        print(f"\n💡 REQUIRED CODE SETTINGS:")
        print(f"  static const int totalClasses = {num_classes};")
        print(f"  Expected output: [1, {anchors}, {features}]")

print("\n" + "="*60)
