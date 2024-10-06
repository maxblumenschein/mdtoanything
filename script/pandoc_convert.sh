#!/bin/bash

# Default template path and template
default_template_path=""
default_template="linear.latex"
pdf_engine="lualatex"

# Prompt for the input file path
read -p "Enter the input file path: " input_path

# Check if the input file exists
if [ ! -f "$input_path" ]; then
    echo "Error: File '$input_path' not found."
    exit 1
fi

# Get the directory of the input file
input_dir=$(dirname "$input_path")

# Prompt for the output file format (PDF, DOCX, ICML)
read -p "Enter the output format (pdf, docx, icml): " output_format

# Ensure the output format is valid
if [[ "$output_format" != "pdf" && "$output_format" != "docx" && "$output_format" != "icml" ]]; then
    echo "Error: Invalid output format '$output_format'. Supported formats are pdf, docx, icml."
    exit 1
fi

# Prompt for the output file path (use input path with appropriate extension if blank)
default_extension=".$output_format"
read -p "Enter the output file path (leave blank to use input file path with .$output_format extension): " output_path
if [ -z "$output_path" ]; then
    output_path="${input_path%.*}$default_extension"
fi

# If the format is PDF, prompt for the template file
if [ "$output_format" == "pdf" ]; then
    read -p "Enter the template file name (leave blank to use default: $default_template): " template_file
    if [ -z "$template_file" ]; then
        template_file="$default_template"
    fi

    # First look for the template file in the default template path
    template_path="$default_template_path$template_file"

    if [ ! -f "$template_path" ]; then
        # If not found, look for the template in the input file directory
        template_path="$input_dir/$template_file"

        if [ ! -f "$template_path" ]; then
            echo "Error: Template file '$template_file' not found in either '$default_template_path' or '$input_dir'."
            exit 1
        fi
    fi
fi

# Change the working directory to the input file directory
cd "$input_dir" || { echo "Error: Failed to change directory to '$input_dir'"; exit 1; }

# Construct the pandoc command based on the chosen output format
if [ "$output_format" == "pdf" ]; then
    # PDF conversion with --standalone
    pandoc_command="pandoc \"$input_path\" -o \"$output_path\" --template=\"$template_path\" --pdf-engine=\"$pdf_engine\" --citeproc --standalone --resource-path=\"$input_dir\""
else
    # DOCX or ICML conversion with --standalone
    pandoc_command="pandoc \"$input_path\" -o \"$output_path\" --citeproc --standalone --resource-path=\"$input_dir\""
fi

# Print the pandoc command to be executed
echo "Executing the following pandoc command in the input directory ($input_dir):"
echo "$pandoc_command"

# Execute the pandoc command
eval $pandoc_command

# Check if pandoc succeeded
if [ $? -eq 0 ]; then
    echo "Conversion successful! Output saved to '$output_path'."
else
    echo "Error: Pandoc failed to convert the file."
fi
