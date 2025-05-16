#!/bin/bash -l

# containing folder.
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
ROOT=$DIR
echo ROOT FOLDER: $ROOT

# path to dependencies.
COMMONS_ROOT="$ROOT/commons/"
CBNT_ROOT="$ROOT/cbnt/"

# python path.
export PYTHONPATH=$COMMONS_ROOT:$CBNT_ROOT:$ROOT:$PYTHONPATH

# JAVA_HOMEの設定
# export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64

python3 codebertnt/codebertnt_runner.py \
-repo_path "$ROOT/test/res/exampleclass/DummyProject" \
-target_classes src/main/java/example/DummyClass.java \
-java_home "$JAVA_HOME" \
-output_dir "$ROOT/test/res/output/cbnt_output_dir/" \
-force_reload "False" \
-cosine "False"

