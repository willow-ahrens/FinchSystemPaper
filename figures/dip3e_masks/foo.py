import os

def replace_parens_in_filenames(directory):
    # Iterate over all files in the specified directory
    for filename in os.listdir(directory):
        # Check if the filename contains parentheses
        if '(' in filename or ')' in filename:
            # Replace parentheses with underscores
            new_filename = filename.replace('(', '_').replace(')', '_')
            # Get the full path of the original and new filenames
            original_path = os.path.join(directory, filename)
            new_path = os.path.join(directory, new_filename)
            # Rename the file
            os.rename(original_path, new_path)
            print(f"Renamed '{filename}' to '{new_filename}'")

# Specify the directory to process
directory_path = '.'
replace_parens_in_filenames(directory_path)
