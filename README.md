# PrintingTools

A specialized collection of automation and pre-press scripts designed to bridge the gap between digital design assets (exported from Figma) and professional, print-ready production files (CMYK PDFs, multi-page document handlers, and automated Adobe Illustrator layouts) tailored for physical game design and publishing.

---

## High-Level Purpose

When preparing board games, card decks, and rulebooks for professional manufacturing, standard RGB-to-PDF converters fall short. They often cause text to look muddy due to rich black registration shifts, force incorrect color spaces, or mismatch physical dimensions and resolutions.

**PrintingTools** automates the entire pre-press workflow:

* **Vector Complexity Slicing:** Isolates fine text and line art from heavy fills to apply crisp 100% K (plain black) or rich black plates precisely where needed.
* **Accurate Color Management:** Converts sRGB design exports into professional CMYK color profiles (such as Coated GRACoL 2006) with strict ICC tagging.
* **Lossless Assembly & PPI Enforcement:** Packages processed image and vector streams into multi-page PDFs or automated Adobe Illustrator templates at exact target resolutions (e.g., 300 PPI).
* **Asset Sorting & Batching:** Organizes raw game component exports, handles duplication counts, and provides robust PDF merging and resizing utilities.

---

## Core Scripts & Tools

### Top-Level Orchestration & Execution

* **`figmaToPdf.sh`** : Top-level orchestrator script that runs the full pipeline: staging, SVG slicing, CMYK separation, lossless PDF compilation, and preflight validation.
* **`execute.sh`** : Comprehensive step-based pipeline orchestrator supporting range-based execution (`--start=N --stop=N`) for sorting, slicing, subtracting, color converting, copying, and generating AI-based component PDFs.

### Color & Pre-Press Processing

* **`ConvertImageColors.sh`** : Performs advanced CMYK channel separation, separates plain text/line art (`_black_full`) from rich black fills (`_black_rich`), and tags ICC color profiles.
* **`sliceSvg.sh`** : Analyzes and slices SVG path complexities to isolate vector text/lines from complex artwork based on configurable thresholds.
* **`subtractSvgFromPng.sh`** : Applies SVG masks directly onto corresponding raster images.
* **`flattenImage.sh`** : Flattens CMYK TIFF images using matching SVG vector masks.

### PDF Manipulation & Assembly

* **`create_pdf.py`** : Python utility leveraging `pypdf`, `img2pdf`, and `natsort` to losslessly wrap sorted image plates into multi-page PDFs and scale bounding boxes to an exact target PPI.
* **`merge_pdfs.py`** : Losslessly merges multiple PDF files matching a glob pattern with natural sorting support and an optional `--ignore-limit` flag for large files.
* **`resize_pdf.py`** : Scales PDF dimensions based on PPI conversion (e.g., converting 72 PPI to 300 PPI) for individual files or entire directories.

### Asset Organization & Batching

* **`sortFiles.sh`** : Sorts, filters, and copies/duplicates raw game components into ordered buckets based on regular expressions, copy counts, and natural/numerical sorting.
* **`copyDir.sh`** : Robust recursive file copying utility with extension filtering and empty directory pruning.
* **`createAIPDF.sh`** & **`CombineLayersToPdf.jsx`** : Integrates with Adobe Illustrator via AppleScript/JSX for template-based batch card and component generation.

### Testing & Verification

* **`run_tests.sh`** : Automated test suite ensuring pipeline output stability against a baseline `GoldenOutput.pdf` with cleanup control flags.

---

## Requirements & Dependencies

To run the pipeline scripts successfully, ensure your environment has the following tools and Python packages installed:

* **ImageMagick (`magick`)**: For image processing, format conversion, and color profile mapping.
* **Poppler Utilities (`pdfimages`, `pdfinfo`)**: For automated preflight stream audits and resolution checks.
* **Python 3.x** with a virtual environment containing:
* `pypdf` (v7.0+)
* `img2pdf`
* `natsort`
* `pillow`


* **Adobe Illustrator** (Optional): Required only if utilizing the `.ai` template automation scripts (`createAIPDF.sh`).
* **ICC Color Profiles**: Standard professional profiles (e.g., `CoatedGRACoL2006.icc`) placed in your system color directories.

---

## Usage Examples

### 1. Compiling Figma Exports into a Print-Ready PDF

```bash
./figmaToPdf.sh -i path/to/figma_exports -o output/GameDeck_PrintReady.pdf -p 300 -c 100

```

**Options (`figmaToPdf.sh`):**

* `-i <dir>` : Directory containing matching Figma PNG and SVG exports.
* `-o <pdf>` : Path and filename of the final CMYK PDF output.
* `-c <num>` : Path complexity threshold for text separation (default: `100`).
* `-p <num>` : Target PPI density for the resulting PDF (default: `300`).
* `-k` : Keep the intermediate `work_pipeline` directory upon completion for inspection.

### 2. Running the Full Modular Pipeline (`execute.sh`)

```bash
# Run the entire pipeline from setup to AI PDF generation
./execute.sh

# Run only a specific step (e.g., Step 6: Create AI PDFs)
./execute.sh --start=6 --stop=6

```

### 3. Merging and Resizing PDFs

```bash
# Losslessly merge chapter PDFs with limit bypass for large files
python3 merge_pdfs.py "chapters/*.pdf" final_rulebook.pdf --ignore-limit

# Resize PDF dimensions from 72 PPI to 300 PPI
python3 resize_pdf.py input.pdf output_scaled.pdf --current 72 --target 300

```

---

## Running the Test Suite

Verify your local setup and script modifications using the built-in test suite:

```bash
# Run standard validation checks against the golden output baseline
./run_tests.sh

# Run tests without cleaning up actual outputs (useful for visual inspection)
./run_tests.sh --no-cleanup

# Update the golden baseline master file after making intentional design/pipeline changes
./run_tests.sh --update

```

---

## License

Distributed under the **MIT License** with an additional physical output liability disclaimer. See the repository `LICENSE` file for full terms.