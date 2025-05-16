#!/bin/bash

# Create necessary directories
mkdir -p test/res/output/cbnt_output_dir
mkdir -p test/res/exampleclass/DummyProject/src/main/java/example

# Run setup.sh to set up dependencies
dependencies_dir="./cbnt_dependencies"
if [ ! -d "$dependencies_dir" ]; then
  echo "Running setup.sh to clone dependencies..."
  bash ./setup.sh "$dependencies_dir"
else
  echo "Dependencies already set up in $dependencies_dir. Skipping setup."
fi

# Build the Docker image
docker build -t codebert-nt .

# Run the Docker container
docker run -it --rm \
    -v "$(pwd)/test:/app/test" \
    -e JAVA_HOME="/usr/lib/jvm/temurin-21-jdk-arm64/" \
    codebert-nt bash

# Run the CodeBERT-NT script inside the container
# bash /app/run_codebertnt.sh