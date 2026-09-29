import argparse
import subprocess
import sys
import os

def get_tags(aseprite_exe, ase_file):
    """Asks Aseprite CLI for a list of tags in the file."""
    try:
        result = subprocess.run(
            [aseprite_exe, "-b", ase_file, "--list-tags"],
            capture_output=True,
            text=True,
            check=True
        )
        # Parse the output, ignoring empty lines
        tags = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        return tags
    except subprocess.CalledProcessError as e:
        print(f"Error reading tags from {ase_file}:\n{e.stderr}")
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: Could not find Aseprite executable at '{aseprite_exe}'.")
        print("Make sure Aseprite is in your system PATH or provide the path using --aseprite.")
        sys.exit(1)

def export_sprite_sheet(aseprite_exe, ase_file, tag, output_dir, prefix):
    """Exports a sprite sheet (and JSON metadata) for a specific tag."""
    if tag:
        output_file = os.path.join(output_dir, f"{prefix}_{tag}.png")
        data_file = os.path.join(output_dir, f"{prefix}_{tag}.json")
        cmd = [
            aseprite_exe, "-b", ase_file,
            "--frame-tag", tag,
            "--sheet", output_file,
            "--data", data_file,
            "--format", "json-array"
        ]
    else:
        # Fallback if the file has no tags, export the whole timeline
        output_file = os.path.join(output_dir, f"{prefix}_full.png")
        data_file = os.path.join(output_dir, f"{prefix}_full.json")
        cmd = [
            aseprite_exe, "-b", ase_file,
            "--sheet", output_file,
            "--data", data_file,
            "--format", "json-array"
        ]

    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(f"  -> Exported: {output_file} (and .json)")
    except subprocess.CalledProcessError as e:
        print(f"Error exporting tag '{tag}':\n{e.stderr}")

def main():
    parser = argparse.ArgumentParser(description="Export Aseprite animations to individual sprite sheets per tag.")
    parser.add_argument("ase_file", help="Path to the .ase or .aseprite file")
    parser.add_argument("-o", "--output-dir", default=".", help="Directory to save the exported sprite sheets")
    parser.add_argument("--aseprite", default="aseprite", help="Path to the Aseprite executable (if not in PATH)")

    args = parser.parse_args()

    if not os.path.isfile(args.ase_file):
        print(f"Error: File '{args.ase_file}' does not exist.")
        sys.exit(1)

    # Ensure output directory exists
    os.makedirs(args.output_dir, exist_ok=True)

    # Get the base filename without extension to use as a prefix
    base_name = os.path.splitext(os.path.basename(args.ase_file))[0]

    print(f"Extracting tags from '{args.ase_file}'...")
    tags = get_tags(args.aseprite, args.ase_file)

    if not tags:
        print("No tags found. Exporting the entire file as a single sprite sheet...")
        export_sprite_sheet(args.aseprite, args.ase_file, None, args.output_dir, base_name)
    else:
        print(f"Found {len(tags)} tag(s): {', '.join(tags)}")
        for tag in tags:
            export_sprite_sheet(args.aseprite, args.ase_file, tag, args.output_dir, base_name)

    print("\nExtraction complete!")

if __name__ == "__main__":
    main()
