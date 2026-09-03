import argparse
import sys
import os
from pathlib import Path
from pypdf import PdfReader, PdfWriter
import pypdf.filters

def resize_single_pdf(input_path, output_path, scale_factor):
    """Core logic to resize a single PDF file."""
    try:
        reader = PdfReader(input_path)
        writer = PdfWriter()

        for page in reader.pages:
            page.scale_by(scale_factor)
            writer.add_page(page)

        with open(output_path, "wb") as f_out:
            writer.write(f_out)
        return True
    except Exception as e:
        print(f"Error processing {input_path}: {e}")
        
        # Check if the error is related to the internal pypdf decompression limits
        if "Limit reached while decompressing" in str(e):
            print("\n[TIP] This file contains large or highly-compressed data streams that exceeded security thresholds.")
            print("      If this file is from a trusted source, re-run this script with the '--ignore-limit' flag.\n")
            
        return False

def main():
    parser = argparse.ArgumentParser(description="Scale PDF dimensions based on PPI conversion.")
    parser.add_argument("input", help="Path to a source PDF file OR a directory of PDFs")
    parser.add_argument("output", help="Path to output PDF file OR output directory")
    parser.add_argument("--current", type=float, default=72.0, help="Current PPI (default: 72.0)")
    parser.add_argument("--target", type=float, default=300.0, help="Target PPI (default: 300.0)")
    
    # New argument to safely bypass decompression limits
    parser.add_argument(
        "--ignore-limit", 
        action="store_true", 
        help="Bypass internal pypdf decompression limits for large, trusted PDF files"
    )

    args = parser.parse_args()
    
    # If the user explicitly passed the flag, lift the decompression caps
    if args.ignore_limit:
        pypdf.filters.ZLIB_MAX_OUTPUT_LENGTH = 0
        pypdf.filters.LZW_MAX_OUTPUT_LENGTH = 0

    scale_factor = args.current / args.target
    
    input_path = Path(args.input)
    output_path = Path(args.output)

    # CASE 1: Input is a Directory
    if input_path.is_dir():
        output_path.mkdir(parents=True, exist_ok=True)
        pdf_files = list(input_path.glob("*.pdf"))
        
        if not pdf_files:
            print(f"No PDF files found in {input_path}")
            return

        print(f"Processing directory: {input_path} -> {output_path}")
        for pdf_file in pdf_files:
            target_file = output_path / pdf_file.name
            if resize_single_pdf(pdf_file, target_file, scale_factor):
                print(f"  [Done] {pdf_file.name}")

    # CASE 2: Input is a Single File
    elif input_path.is_file():
        final_output = output_path
        if output_path.is_dir() or args.output.endswith('/'):
            output_path.mkdir(parents=True, exist_ok=True)
            final_output = output_path / input_path.name

        if resize_single_pdf(input_path, final_output, scale_factor):
            print(f"Successfully scaled: {input_path.name} -> {final_output}")

    else:
        print(f"Error: Input path '{args.input}' does not exist.")
        sys.exit(1)

if __name__ == "__main__":
    main()