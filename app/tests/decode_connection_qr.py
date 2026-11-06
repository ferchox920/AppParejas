"""Independent QR decoder for the texture exported by Godot's invitation screen."""
import sys

from PIL import Image
import zxingcpp

with Image.open(sys.argv[1]) as image:
    results = zxingcpp.read_barcodes(image, formats=zxingcpp.BarcodeFormat.QRCode)
if len(results) != 1 or not results[0].text:
    raise SystemExit("Se esperaba exactamente un QR con contenido")
print(results[0].text)
