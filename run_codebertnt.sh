#!/bin/bash -l

# Set the root directory
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
ROOT=$DIR
echo ROOT FOLDER: $ROOT

# Set PYTHONPATH
export PYTHONPATH="$PWD/cbnt_dependencies/commons:$PWD/cbnt_dependencies/cbnt:/app:$PYTHONPATH"

# Set JAVA_HOME to match Java 21
export JAVA_HOME="/usr/lib/jvm/temurin-21-jdk-arm64/"

# Run the Python script
python3 codebertnt/codebertnt_runner.py \
-repo_path "$ROOT/test/res/exampleclass/DummyProject" \
-target_classes src/main/java/example/DummyClass.java \
-java_home "$JAVA_HOME" \
-output_dir "$ROOT/test/res/output/cbnt_output_dir/" \
-force_reload "False" \
-cosine "False"