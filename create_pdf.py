# pvenv
# pip install img2pdf pypdf pillow natsort
# python create_pdf.py "work_pipeline/2_converted_tiffs/*_final.tiff" output.pdf --ppi 300.0

import glob
import io
import img2pdf
import argparse
import sys
from pypdf import PdfReader, PdfWriter
from PIL import Image
from natsort import natsorted

def build_pdf(image_pattern, output_pdf, target_ppi):
    # 1. Grab all image paths matching the pattern
    raw_files = glob.glob(image_pattern)
    
    # 2. Apply Natural Sorting (Fixes the 1, 10, 2 issue)
    image_paths = natsorted(raw_files)

    if not image_paths:
        print(f"Error: No images found matching pattern '{image_pattern}'")
        return
        
    print(f"Found {len(image_paths)} images. Wrapping losslessly...")

    # 2. Convert images to PDF bytes
    try:
        raw_pdf_bytes = img2pdf.convert(image_paths)
        pdf_stream = io.BytesIO(raw_pdf_bytes)
    except Exception as e:
        print(f"Error during image conversion: {e}")
        return

    # 3. Read into pypdf to fix dimensions
    reader = PdfReader(pdf_stream)
    writer = PdfWriter()

    print(f"Scaling bounding boxes to exactly {target_ppi} PPI...")
    
    for i, page in enumerate(reader.pages):
        img_path = image_paths[i]
        
        with Image.open(img_path) as img:
            w_px, h_px = img.size
            
        # Physical size calculation (72 points per inch)
        target_w_pt = (w_px / target_ppi) * 72.0
        
        # Calculate scale factor based on width
        current_w_pt = float(page.mediabox.width)
        scale_factor = target_w_pt / current_w_pt
        
        page.scale_by(scale_factor) 
        writer.add_page(page)

    # 4. Save to disk
    with open(output_pdf, "wb") as f_out:
        writer.write(f_out)

    print(f"Success! Saved perfectly scaled images to: {output_pdf}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compile a folder of images into a correctly scaled PDF.")
    
    # Required arguments
    parser.add_argument("pattern", help="Input file pattern (e.g., 'images/*.jpg' or '*.png')")
    parser.add_argument("output", help="Output PDF filename (e.g., 'portfolio.pdf')")
    
    # Optional arguments
    parser.add_argument("--ppi", type=float, default=300.0, help="Target PPI for the PDF (default: 300.0)")

    args = parser.parse_args()

    # Safety check: prevent overwriting source files if args are swapped
    if not args.output.lower().endswith(".pdf"):
        print("Error: Output filename must end with .pdf")
        sys.exit(1)

    build_pdf(args.pattern, args.output, args.ppi)
