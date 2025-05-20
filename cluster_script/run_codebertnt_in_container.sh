#!/bin/bash
set -e

# --- スクリプト引数の受け取り ---
ARG_REPO_PATH="$1"                # $1: コンテナ内のリポジトリのルートパス (例: /mnt/repo)
ARG_TARGET_CLASSES_RELATIVE_PATH="$2" # $2: リポジトリルートからのターゲットファイルの相対パス
ARG_OUTPUT_DIR="$3"               # $3: コンテナ内の出力ディレクトリパス (例: /mnt/output)
ARG_JAVA_HOME="$4"                # $4: コンテナ内のJava Homeパス
APP_ROOT="${5:-/app}"             # $5: コンテナ内のアプリケーションスクリプトのルートパス (デフォルト /app)

# --- 固定パラメータ (必要に応じてSlurmスクリプトから引数として渡すように変更可能) ---
PYTHON_EXECUTABLE="python"
# ★APP_ROOT からの相対パス。Singularity定義ファイルの %files でのコピー先と合わせる★
CODEBERT_RUNNER_SCRIPT_RELATIVE_PATH="codebertnt/codebertnt_runner.py" 
FORCE_RELOAD="False"
COSINE_LOGIC="False" # Pythonのboolとして解釈されるように渡す場合は調整

# --- 処理開始ログ ---
echo "-----------------------------------------------------"
echo "--- Starting task inside Singularity container ---"
echo "Timestamp: $(date)"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID:-N/A}, SLURM_ARRAY_TASK_ID: ${SLURM_ARRAY_TASK_ID:-N/A}" # Slurm環境変数はコンテナ内に引き継がれることが多い
echo "Container Hostname: $(hostname)"
echo "-----------------------------------------------------"
echo "Received Arguments:"
echo "  Repository Path (in container): ${ARG_REPO_PATH}"
echo "  Target Classes (relative path): ${ARG_TARGET_CLASSES_RELATIVE_PATH}"
echo "  Output Directory (in container): ${ARG_OUTPUT_DIR}"
echo "  Java Home (in container): ${ARG_JAVA_HOME}"
echo "  Application Root (in container): ${APP_ROOT}"
echo ""
echo "Fixed Parameters:"
echo "  Python Executable: ${PYTHON_EXECUTABLE}"
echo "  CodeBERT Runner Script (relative to APP_ROOT): ${CODEBERT_RUNNER_SCRIPT_RELATIVE_PATH}"
echo "  Force Reload: ${FORCE_RELOAD}"
echo "  Cosine Logic: ${COSINE_LOGIC}"
echo "-----------------------------------------------------"

# --- パスとファイルの検証 ---
CODEBERT_RUNNER_FULL_PATH="${APP_ROOT}/${CODEBERT_RUNNER_SCRIPT_RELATIVE_PATH}"
if [ ! -f "${CODEBERT_RUNNER_FULL_PATH}" ]; then
    echo "エラー(コンテナ内): CodeBERT実行スクリプトが見つかりません: ${CODEBERT_RUNNER_FULL_PATH}"
    exit 1
fi
echo "コンテナ内: CodeBERT実行スクリプト確認OK: ${CODEBERT_RUNNER_FULL_PATH}"

if [ ! -d "${ARG_REPO_PATH}" ]; then
    echo "エラー(コンテナ内): 指定されたリポジトリパスが見つかりません: ${ARG_REPO_PATH}"
    exit 1
fi
echo "コンテナ内: リポジトリパス確認OK: ${ARG_REPO_PATH}"

TARGET_FILE_FULL_PATH_IN_CONTAINER="${ARG_REPO_PATH}/${ARG_TARGET_CLASSES_RELATIVE_PATH}"
if [ ! -f "${TARGET_FILE_FULL_PATH_IN_CONTAINER}" ]; then
    echo "エラー(コンテナ内): 指定されたターゲットファイルがリポジトリ内に見つかりません: ${TARGET_FILE_FULL_PATH_IN_CONTAINER}"
    echo "  (相対パス: ${ARG_TARGET_CLASSES_RELATIVE_PATH} at リポジトリ: ${ARG_REPO_PATH})"
    exit 1
fi
echo "コンテナ内: ターゲットファイル確認OK: ${TARGET_FILE_FULL_PATH_IN_CONTAINER}"

if [ ! -d "${ARG_OUTPUT_DIR}" ]; then
    echo "警告(コンテナ内): 指定された出力ディレクトリが見つかりません: ${ARG_OUTPUT_DIR}"
    echo "                 ディレクトリを作成します。"
    mkdir -p "${ARG_OUTPUT_DIR}"
    if [ ! -d "${ARG_OUTPUT_DIR}" ]; then
        echo "エラー(コンテナ内): 出力ディレクトリの作成に失敗しました: ${ARG_OUTPUT_DIR}"
        exit 1
    fi
fi
echo "コンテナ内: 出力ディレクトリ確認OK: ${ARG_OUTPUT_DIR}"

if [ ! -d "${ARG_JAVA_HOME}" ] || [ ! -x "${ARG_JAVA_HOME}/bin/java" ]; then
    echo "警告(コンテナ内): 指定されたJava Homeパス '${ARG_JAVA_HOME}' が無効か、java実行ファイルが見つかりません。"
fi
echo "コンテナ内: Java Home確認: ${ARG_JAVA_HOME}"
echo "-----------------------------------------------------"

# --- CodeBERT-nt Pythonスクリプトの実行 ---
echo "コンテナ内: codebertnt_runner.py を実行します..."
echo "PYTHONPATH: ${PYTHONPATH}" # Singularity定義ファイルで設定されているはず
echo "現在のコンテナ内ディレクトリ: $(pwd)" # 通常はコンテナのルート /

# デバッグ用にリポジトリパスのリストを表示
echo "コンテナ内: リポジトリパス (${ARG_REPO_PATH}) の内容:"
ls -la "${ARG_REPO_PATH}"

set -x # 実行するコマンドをログに出力する

"${PYTHON_EXECUTABLE}" "${CODEBERT_RUNNER_FULL_PATH}" \
    -repo_path "${ARG_REPO_PATH}" \
    -target_classes "${ARG_TARGET_CLASSES_RELATIVE_PATH}" \
    -java_home "${ARG_JAVA_HOME}" \
    -output_dir "${ARG_OUTPUT_DIR}" \
    -force_reload "${FORCE_RELOAD}" \
    -cosine "${COSINE_LOGIC}" \
    # -all_lines "True" # codebertnt_runner.py がこの引数を受け付ける場合、適切に設定
    # -project_name "${PROJECT_NAME_OWNER_REPO}" # Slurmスクリプトから追加で引数として渡す必要あり
    # -max_processes "1" # コンテナ内では通常1プロセス (Slurmのcpus-per-taskに応じて調整)

RUNNER_EXIT_CODE=$?
set +x

echo "-----------------------------------------------------"
if [ ${RUNNER_EXIT_CODE} -ne 0 ]; then
    echo "エラー(コンテナ内): codebertnt_runner.py の実行が失敗しました。終了コード: ${RUNNER_EXIT_CODE}"
else
    echo "コンテナ内: codebertnt_runner.py は正常に終了しました。"
fi
echo "Timestamp: $(date)"
echo "--- Task inside Singularity container finished ---"
echo "-----------------------------------------------------"

exit ${RUNNER_EXIT_CODE}
