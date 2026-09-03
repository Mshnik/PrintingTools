# pvenv
# pip install natsort

import glob
import argparse
import sys
from pypdf import PdfWriter
from natsort import natsorted
import pypdf.filters

def merge_pdfs_losslessly(input_pattern, output_pdf):
    # 1. Grab all PDF paths matching the pattern
    raw_files = glob.glob(input_pattern)
    
    # 2. Apply Natural Sorting (Fixes the 1, 10, 2 issue)
    pdf_files = natsorted(raw_files)
    
    # Safety check: Prevent merging the output file into itself
    if output_pdf in pdf_files:
        pdf_files.remove(output_pdf)

    if not pdf_files:
        print(f"Error: No PDFs found matching '{input_pattern}'")
        return
        
    print(f"Found {len(pdf_files)} PDF files. Merging losslessly...")

    # 2. Append pages without altering content streams
    writer = PdfWriter()
    
    try:
        for pdf_path in pdf_files:
            print(f" -> Appending: {pdf_path}")
            writer.append(pdf_path)

        # 3. Save the final compiled file to disk
        with open(output_pdf, "wb") as f_out:
            writer.write(f_out)
        
        print(f"\nSuccess! Merged {len(pdf_files)} files into: {output_pdf}")

    except Exception as e:
        print(f"An error occurred during merging: {e}")
        
        # Intercept stream-size and decompression limit exceptions
        if "exceeds maximum allowed length" in str(e) or "Limit reached" in str(e):
            print("\n[TIP] One or more files contain data streams that exceed pypdf's safety thresholds.")
            print("      If you trust these files, re-run this script with the '--ignore-limit' flag.\n")
            
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Merge multiple PDF files into one losslessly using a file pattern."
    )
    
    # Required arguments
    parser.add_argument(
        "pattern", 
        help="The glob pattern to match PDF files (e.g., 'chapter_*.pdf' or 'docs/*.pdf')"
    )
    parser.add_argument(
        "output", 
        help="The name of the resulting merged PDF file"
    )

    parser.add_argument(
        "--ignore-limit", 
        action="store_true", 
        help="Bypass internal pypdf decompression and stream length limits for large, trusted PDF files"
    )

    args = parser.parse_args()

    # If the user explicitly passed the flag, lift all structural and decompression caps
    if args.ignore_limit:
        # 1. Clear decompression filter caps (0 explicitly signals 'unlimited' here)
        pypdf.filters.ZLIB_MAX_OUTPUT_LENGTH = 0
        pypdf.filters.LZW_MAX_OUTPUT_LENGTH = 0
        
        # 2. Clear object stream layout caps (requires infinity to disable comparison math)
        pypdf.filters.MAX_DECLARED_STREAM_LENGTH = float('inf')
        pypdf.filters.MAX_ARRAY_BASED_STREAM_OUTPUT_LENGTH = float('inf')

    # Simple validation for output extension
    if not args.output.lower().endswith(".pdf"):
        print("Warning: Your output filename does not end in '.pdf'. Adding it now.")
        args.output += ".pdf"

    merge_pdfs_losslessly(args.pattern, args.output)