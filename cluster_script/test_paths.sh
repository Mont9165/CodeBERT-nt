#!/bin/bash
#SBATCH --job-name=path_debug_test
#SBATCH --output=/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/logs/test_output_%A_%a.txt # ★ログ出力先(絶対パス)★
#SBATCH --error=/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/logs/test_error_%A_%a.txt  # ★ログ出力先(絶対パス)★
#SBATCH --array=0-0
#SBATCH --time=0-00:02:00 # 2分
#SBATCH --partition=msas_short # ★NAISTクラスタの適切なパーティション名★

echo "--- Test Script Started ---"
echo "Job ID: ${SLURM_JOB_ID}, Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "SLURM_SUBMIT_DIR (Directory where sbatch was run): ${SLURM_SUBMIT_DIR}"
echo "PWD (Initial current working directory for the job): $(pwd)"
echo "---"

# プロジェクトルートをハードコードで定義
MY_PROJECT_ROOT="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt"
echo "MY_PROJECT_ROOT is defined as: '${MY_PROJECT_ROOT}'"

# ログディレクトリを作成しようとしてみる (ターゲットの親ディレクトリは存在すると仮定)
MY_LOG_DIR="${MY_PROJECT_ROOT}/logs_from_script" # SBATCHディレクティブとは別のテスト用ログディレクトリ
echo "Attempting to create directory: '${MY_LOG_DIR}'"
mkdir -p "${MY_LOG_DIR}"
if [ -d "${MY_LOG_DIR}" ]; then
    echo "Successfully created or found directory: '${MY_LOG_DIR}'"
    echo "Test content" > "${MY_LOG_DIR}/test_file_in_script_log_dir.txt"
else
    echo "ERROR: Failed to create directory: '${MY_LOG_DIR}'"
fi
echo "---"

# tasks.list (仮のパス) を確認しようとしてみる
MY_TASKS_LIST_PATH="${MY_PROJECT_ROOT}/tasks.list" # 実際のtasks.listのパスに合わせてください
echo "Checking for MY_TASKS_LIST_PATH: '${MY_TASKS_LIST_PATH}'"
if [ -f "${MY_TASKS_LIST_PATH}" ]; then
    echo "MY_TASKS_LIST_PATH exists."
else
    echo "ERROR: MY_TASKS_LIST_PATH does NOT exist."
    echo "Attempting to list parent directory of MY_TASKS_LIST_PATH: $(ls -ld "$(dirname "${MY_TASKS_LIST_PATH}")" )"
fi
echo "---"

echo "--- Test Script Finished ---"
exit 0
