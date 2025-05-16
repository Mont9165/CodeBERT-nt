#!/bin/bash

# 必要なディレクトリを作成
mkdir -p test/res/output/cbnt_output_dir
mkdir -p test/res/exampleclass/DummyProject/src/main/java/example

# イメージのビルド
docker build -t codebert-nt .

# コンテナの実行
docker run -it --rm \
    -v "$(pwd)/test:/app/test" \
    -v "$(pwd)/output:/app/output" \
    codebert-nt