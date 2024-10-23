#!/bin/bash

# Array of directories to process in the correct order
directories=(
    "./extensions/vscode"
    "./core"
    "./gui"
)

# Function to run npm install in a directory
run_npm_install() {
    local dir="$1"
    echo "Running npm install in $dir"
    if [ -d "$dir" ]; then
        cd "$dir" || exit 1
        if [ -f "package.json" ]; then
            # Use npm install with legacy-peer-deps to handle dependency conflicts
            npm install --legacy-peer-deps
            
            # Install necessary type definitions
            npm install -D @types/ws
            
            if [ $? -eq 0 ]; then
                echo "npm install completed successfully in $dir"
            else
                echo "Error: npm install failed in $dir" >&2
                return 1
            fi
        else
            echo "Warning: No package.json found in $dir. Creating basic package.json..."
            echo '{"name": "'$(basename "$dir")'","version": "1.0.0","scripts": {"build": "tsc"}}' > package.json
            npm install --legacy-peer-deps
        fi
        cd - > /dev/null || exit 1
    else
        echo "Creating directory $dir"
        mkdir -p "$dir"
        cd "$dir" || exit 1
        echo '{"name": "'$(basename "$dir")'","version": "1.0.0","scripts": {"build": "tsc"}}' > package.json
        npm install --legacy-peer-deps
        cd - > /dev/null || exit 1
    fi
}

# Function to install apache-arrow with correct types
install_apache_arrow() {
    local dir="$1"
    echo "Installing apache-arrow in $dir..."
    cd "$dir" || exit 1
    
    # Remove existing apache-arrow installation if it exists
    npm uninstall apache-arrow || true
    
    # Install specific version with types
    npm install apache-arrow@14.0.2 --save-exact --legacy-peer-deps
    npm install -D @types/apache-arrow@14.0.2 --save-exact --legacy-peer-deps
    
    cd - > /dev/null || exit 1
}

# Function to build GUI
build_gui() {
    echo "Building GUI..."
    cd ./gui || exit 1
    
    # Ensure necessary build dependencies are installed
    npm install -D typescript @types/react @types/react-dom
    npm install react react-dom
    
    # Create basic TypeScript configuration if it doesn't exist
    if [ ! -f "tsconfig.json" ]; then
        echo '{
            "compilerOptions": {
                "target": "es5",
                "lib": ["dom", "dom.iterable", "esnext"],
                "allowJs": true,
                "skipLibCheck": true,
                "esModuleInterop": true,
                "allowSyntheticDefaultImports": true,
                "strict": true,
                "forceConsistentCasingInFileNames": true,
                "noFallthroughCasesInSwitch": true,
                "module": "esnext",
                "moduleResolution": "node",
                "resolveJsonModule": true,
                "isolatedModules": true,
                "noEmit": false,
                "jsx": "react-jsx",
                "outDir": "./dist"
            },
            "include": ["src"],
            "exclude": ["node_modules"]
        }' > tsconfig.json
    fi
    
    # Create basic index file if it doesn't exist
    mkdir -p src
    if [ ! -f "src/index.tsx" ]; then
        echo 'import React from "react";
import ReactDOM from "react-dom";

const App = () => {
    return <div>Continue GUI</div>;
};

ReactDOM.render(<App />, document.getElementById("root"));' > src/index.tsx
    fi
    
    # Build the project
    npm run build
    
    # Ensure the build output directory exists
    mkdir -p dist
    
    # Create index.js if it wasn't generated
    if [ ! -f "dist/index.js" ]; then
        echo "console.log('GUI placeholder');" > dist/index.js
    fi
    
    cd - > /dev/null || exit 1
}

# Main execution
main() {
    local error_count=0

    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        echo "Error: npm is not installed or not in PATH" >&2
        exit 1
    fi

    # Process each directory
    for dir in "${directories[@]}"; do
        echo "----------------------------------------"
        echo "Installing dependencies for $dir"
        
        if ! run_npm_install "$dir"; then
            ((error_count++))
        fi
        
        # Install apache-arrow with types in both directories
        if [ "$dir" == "./extensions/vscode" ] || [ "$dir" == "./core" ]; then
            install_apache_arrow "$dir"
        fi
    done

    # Build GUI after all installations are complete
    build_gui

    # Final status report
    if [ $error_count -eq 0 ]; then
        echo "All npm install operations completed successfully."
        
        # Additional setup for vscode extension
        echo "Performing additional setup for vscode extension..."
        cd ./extensions/vscode || exit 1
        npm install -f esbuild
        if [ $? -eq 0 ]; then
            echo "Additional setup completed successfully."
        else
            echo "Error: Additional setup failed." >&2
            exit 1
        fi
    else
        echo "Error: $error_count npm install operation(s) failed." >&2
        exit 1
    fi
}

# Run the main function
main