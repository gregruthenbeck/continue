#!/bin/bash

# Array of directories to process
directories=(
    "./core"
    "./gui"
    "./extensions/vscode"
)

# Function to run yarn install in a directory
run_yarn_install() {
    local dir="$1"
    echo "Running yarn install in $dir"
    if [ -d "$dir" ]; then
        cd "$dir" || exit 1
        if [ -f "package.json" ]; then
            yarn install
            if [ $? -eq 0 ]; then
                echo "yarn install completed successfully in $dir"
            else
                echo "Error: yarn install failed in $dir" >&2
                return 1
            fi
        else
            echo "Warning: No package.json found in $dir. Skipping." >&2
        fi
        cd - > /dev/null || exit 1
    else
        echo "Error: Directory $dir not found" >&2
        return 1
    fi
}

# Main execution
main() {
    local error_count=0

    # Check if yarn is installed
    if ! command -v yarn &> /dev/null; then
        echo "Error: yarn is not installed or not in PATH" >&2
        exit 1
    fi

    # Process each directory
    for dir in "${directories[@]}"; do
        if ! run_yarn_install "$dir"; then
            ((error_count++))
        fi
        echo "----------------------------------------"
    done

    # Final status report
    if [ $error_count -eq 0 ]; then
        echo "All yarn install operations completed successfully."
    else
        echo "Error: $error_count yarn install operation(s) failed." >&2
        exit 1
    fi

    # Do fixes from `.github/workflows/main.yaml`
    echo "Re-install esbuild to fix common workflow/build issues..."
    # cd ./extensions/vscode && yarn add @typescript-eslint/eslint-plugin apache-arrow && npm install -f esbuild
    cd ./extensions/vscode && yarn add -D @types/ws && npm install -f esbuild
    echo "Re-install esbuild to fix common workflow/build issues... done!"
}

# Run the main function
main
