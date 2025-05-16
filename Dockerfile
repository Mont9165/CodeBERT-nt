FROM python:3.9-slim

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    vim \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Eclipse Temurinのリポジトリを追加
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - \
    && echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list

# Java 21のインストール
RUN apt-get update && apt-get install -y temurin-21-jdk \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリの設定
WORKDIR /app

# 必要なPythonパッケージをインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ソースコードのコピー
COPY . .

# 環境変数の設定
ENV PYTHONPATH=/app:/app/commons:/app/cbnt:$PYTHONPATH
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64

# 実行コマンド
CMD ["bash", "run_codebertnt.sh"]