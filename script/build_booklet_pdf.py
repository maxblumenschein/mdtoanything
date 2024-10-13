import os
import PyPDF2
from PyPDF2 import PdfWriter, PdfReader

# A4 page size in points (width, height)
A4_WIDTH = 595.28
A4_HEIGHT = 841.89

def rearrange_pages_for_booklet(input_pdf_path, use_layers=False, pages_per_layer=20):
    """
    Rearranges PDF pages for booklet printing.
    Optionally, organizes pages into layers for thread binding if 'use_layers' is True.

    :param input_pdf_path: Path to the input PDF file.
    :param use_layers: Boolean flag to indicate whether to use layers for thread binding.
    :param pages_per_layer: Number of pages per binding layer (only used if use_layers is True).
    """
    # Read the input PDF
    reader = PdfReader(input_pdf_path)
    total_pages = len(reader.pages)

    # Create a new PDF writer object
    writer = PdfWriter()

    # Calculate the number of blank pages needed to make total pages a multiple of 4
    if total_pages % 4 != 0:
        blank_pages_to_add = 4 - (total_pages % 4)
    else:
        blank_pages_to_add = 0

    # Add original pages to the output PDF
    for page in reader.pages:
        writer.add_page(page)

    # Add blank pages at the end if necessary
    for _ in range(blank_pages_to_add):
        writer.add_blank_page(width=A4_WIDTH, height=A4_HEIGHT)

    # Adjust total pages after adding blank pages
    total_pages_after_adding_blanks = len(writer.pages)

    # Prepare for booklet layout by processing pages
    final_writer = PdfWriter()

    if use_layers:
        # Rearrange and reorder the pages per layer if layers are being used
        for layer_start in range(0, total_pages_after_adding_blanks, pages_per_layer):
            layer_end = min(layer_start + pages_per_layer, total_pages_after_adding_blanks)
            layer_size = layer_end - layer_start

            # Ensure that each layer has a multiple of 4 pages (needed for booklet printing)
            if layer_size % 4 != 0:
                blanks_needed = 4 - (layer_size % 4)
                layer_size += blanks_needed
                for _ in range(blanks_needed):
                    writer.add_blank_page(width=A4_WIDTH, height=A4_HEIGHT)
                total_pages_after_adding_blanks = len(writer.pages)

            # Generate the page order for booklet printing for this layer
            booklet_page_order = []
            half_layer_size = layer_size // 2

            for i in range(half_layer_size):
                left_page = layer_start + (layer_size - 1 - i)
                right_page = layer_start + i
                booklet_page_order.append((left_page, right_page))

            # Add pages in the correct booklet order for this layer
            for left_page, right_page in booklet_page_order:
                # Always add the left page
                final_writer.add_page(writer.pages[left_page])

                # Add the right page (if it's within bounds)
                if right_page < total_pages_after_adding_blanks:
                    final_writer.add_page(writer.pages[right_page])
    else:
        # Rearrange the pages without layering (just for the whole booklet)
        booklet_page_order = []
        for i in range(total_pages_after_adding_blanks // 2):
            left_page = total_pages_after_adding_blanks - 1 - i
            right_page = i
            booklet_page_order.append((left_page, right_page))

        # Add pages in the correct booklet order for the whole document
        for left_page, right_page in booklet_page_order:
            final_writer.add_page(writer.pages[left_page])

            if right_page < total_pages_after_adding_blanks:
                final_writer.add_page(writer.pages[right_page])

    # Create a "print" directory inside the input PDF directory
    input_directory = os.path.dirname(input_pdf_path)
    output_directory = os.path.join(input_directory, 'print')

    # Create the "print" folder if it doesn't exist
    os.makedirs(output_directory, exist_ok=True)

    # Get the input file name without extension
    input_file_name = os.path.splitext(os.path.basename(input_pdf_path))[0]

    # Define the output file name with the correct suffix
    if use_layers:
        output_pdf_name = f"{input_file_name}_{pages_per_layer}pages-per-layer_booklet.pdf"
    else:
        output_pdf_name = f"{input_file_name}_booklet.pdf"

    # Define the output file path
    output_pdf_path = os.path.join(output_directory, output_pdf_name)

    # Write the output PDF
    with open(output_pdf_path, 'wb') as output_pdf:
        final_writer.write(output_pdf)

    print(f"Booklet PDF created and saved to {output_pdf_path}")

# Usage
input_pdf = 'input.pdf'  # Replace with your input PDF file path
use_layers = True  # Set this to True if you want to use layering for thread binding
pages_per_layer = 16  # Define how many pages per layer (only used if use_layers is True)
rearrange_pages_for_booklet(input_pdf, use_layers=use_layers, pages_per_layer=pages_per_layer)
