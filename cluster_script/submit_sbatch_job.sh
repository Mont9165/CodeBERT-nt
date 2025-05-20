
#!/bin/bash

# --- SBATCH Directives ---
#SBATCH --job-name=codebert_nt_batch
#SBATCH --output=/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/logs/slurm_job_output_%A_%a.out    # プロジェクトルート/logs/ に出力
#SBATCH --error=/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/error/slurm_job_error_%A_%a.err     # プロジェクトルート/logs/ に出力 (以前は slurm_errors でしたが logs に統一)
#SBATCH --array=0-2 # ★重要★ tasks.list の (総行数 - 1) に必ず調整。テスト時は 0-0 や 0-2 など。
#SBATCH --time=0-10:30:00      # 1タスクあたりの最大実行時間 (例: 30分) - ★要調整★
#SBATCH --partition=ocigpu1a10_long  # ★重要★ NAISTクラスタの適切な本番用パーティション名に変更 (msas_intr はインタラクティブ用)
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2      # ★要調整★ codebertnt_runner.py の -max_processes と関連
#SBATCH --mem=32G               # ★要調整★
##SBATCH --gres=gpu:1          # GPUを使用する場合にコメント解除し、必要なGPU数と種類を指定

# --- Configuration (このセクションのパスや設定を必ずご自身の環境に合わせてください) ---

# このスクリプト自身の場所を基準にするための設定 (推奨)
SCRIPT_DIR_SLURM=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT_DIR="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt"

# Singularityイメージファイルのパス
SINGULARITY_IMAGE_PATH="${PROJECT_ROOT_DIR_SLURM}/codebert-nt.sif" # ★要確認/変更★ (プロジェクトルート直下にあると仮定)

# tasks.list ファイルのパス
TASK_LIST_FILE="${PROJECT_ROOT_DIR_SLURM}/tasks.list" # ★要確認/変更★

# 各タスクがGitリポジトリを一時的にクローン/チェックアウトするためのホスト上のベースディレクトリ
# 高速なスクラッチディスク領域を推奨 (ユーザーのホームやworkディレクトリ以下に作成)
HOST_TEMP_WORK_BASE_DIR="/work/kosei-ho/scratch/codebert_temp_work_batch" # ★要確認/変更★

# CodeBERT-nt の最終的な解析結果を保存するホスト上のベースディレクトリ
HOST_FINAL_OUTPUT_BASE_DIR="${PROJECT_ROOT_DIR_SLURM}/results_batch" # ★要確認/変更★

# --- コンテナ内パス設定 ---
CONTAINER_PROJECT_MOUNT_POINT="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/repo"  # クローンされたリポジトリがコンテナ内で見える場所
CONTAINER_OUTPUT_MOUNT_POINT="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/output" # 出力ディレクトリがコンテナ内で見える場所
# Singularityイメージ内の実行スクリプト (run_codebertnt_in_container.sh) のフルパス
CONTAINER_APP_SCRIPT_PATH="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/cluster_script/run_codebertnt_in_container.sh" # ★イメージ内のパス★
# Singularityイメージ内のJAVA_HOMEパス
CONTAINER_JAVA_HOME="/usr/lib/jvm/temurin-21-jdk-amd64/" # ★イメージ内のJDKパスに合わせる★
# Singularityイメージ内のアプリケーションルート (codebertnt_runner.py等の基準)
CONTAINER_APP_ROOT="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt/" # ★イメージ内の構造に合わせる★

# --- End Configuration ---

# --- 事前準備 ---
echo "--- SLURM Job Information (Task ${SLURM_ARRAY_TASK_ID}) ---"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"
echo "SLURM_ARRAY_JOB_ID: ${SLURM_ARRAY_JOB_ID}"
echo "Host: $(hostname)"
echo "Executing Directory: $(pwd)"
echo "Project Root (derived): ${PROJECT_ROOT_DIR_SLURM}"
echo "Singularity Image: ${SINGULARITY_IMAGE_PATH}"
echo "Task List File: ${TASK_LIST_FILE}"
echo "Host Temp Work Base: ${HOST_TEMP_WORK_BASE_DIR}"
echo "Host Final Output Base: ${HOST_FINAL_OUTPUT_BASE_DIR}"
echo "----------------------------------------------------"

# ログディレクトリ、出力ベースディレクトリ、一時作業ベースディレクトリの作成
# sbatch実行時のカレントディレクトリ(PROJECT_ROOT_DIR_SLURMを想定)にlogsディレクトリを作成
mkdir -p "${PROJECT_ROOT_DIR_SLURM}/logs" \
         "${HOST_TEMP_WORK_BASE_DIR}" "${HOST_FINAL_OUTPUT_BASE_DIR}"

# Singularityモジュールのロード (NAISTクラスタの環境に合わせて)
echo "Loading Singularity module..."
module purge
module load singularity # ★NAISTクラスタのSingularityバージョンに合わせて変更★
echo "Singularity called"

# --- タスク処理 ---
# tasks.list から現在のタスクIDに対応する行を読み込む
# tasks.list のフォーマット (想定):
# 0:project_name_owner_repo, 1:commit_id, 2:target_file_path_in_repo,
# 3:output_identifier, 4:repository_url, 5:reference_repo_path_or_empty
CURRENT_TASK_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "${TASK_LIST_FILE}")

if [ -z "${CURRENT_TASK_LINE}" ]; then
    echo "エラー: タスクID ${SLURM_ARRAY_TASK_ID} に対応する行が ${TASK_LIST_FILE} に見つかりません。"
    exit 1
fi

IFS=',' read -r PROJECT_NAME_OWNER_REPO COMMIT_ID TARGET_FILE_IN_REPO \
                OUTPUT_IDENTIFIER REPOSITORY_URL REFERENCE_REPO_PATH <<< "${CURRENT_TASK_LINE}"

echo "--- Current Task Details (ID: ${SLURM_ARRAY_TASK_ID}) ---"
echo "Project Name (owner_reponame): ${PROJECT_NAME_OWNER_REPO}"
echo "Commit ID: ${COMMIT_ID}"
echo "Target File in Repo: ${TARGET_FILE_IN_REPO}"
echo "Output Identifier: ${OUTPUT_IDENTIFIER}"
echo "Repository URL: ${REPOSITORY_URL}"
echo "Reference Repo Path: ${REFERENCE_REPO_PATH:-N/A}" # 空の場合は N/A と表示
echo "-------------------------------------------------"

# --- 各タスク固有のディレクトリ設定 ---
HOST_TASK_WORK_DIR="${HOST_TEMP_WORK_BASE_DIR}/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}_${PROJECT_NAME_OWNER_REPO//\//_}"
mkdir -p "${HOST_TASK_WORK_DIR}"
echo "Host task work directory: ${HOST_TASK_WORK_DIR}"

HOST_TASK_FINAL_OUTPUT_DIR="${HOST_FINAL_OUTPUT_BASE_DIR}/${OUTPUT_IDENTIFIER}"
mkdir -p "${HOST_TASK_FINAL_OUTPUT_DIR}"
echo "Host task final output directory: ${HOST_TASK_FINAL_OUTPUT_DIR}"

# --- Gitリポジトリの準備 ---
echo "リポジトリ (${REPOSITORY_URL}) を ${HOST_TASK_WORK_DIR} に準備しています..."
# (安全のため、Git操作前にカレントディレクトリを明示的に設定)
cd "${HOST_TASK_WORK_DIR}" || { echo "エラー: ${HOST_TASK_WORK_DIR} へのcdに失敗"; exit 1; }
TEMP_GIT_DIR_NAME=$(basename "${REPOSITORY_URL}" .git)
ACTUAL_GIT_REPO_PATH_ON_HOST="${HOST_TASK_WORK_DIR}/${TEMP_GIT_DIR_NAME}"

GIT_CLONE_CMD="git clone --quiet"
if [ -n "${REFERENCE_REPO_PATH}" ] && [ -d "${REFERENCE_REPO_PATH}" ]; then
    echo "参照リポジトリ ${REFERENCE_REPO_PATH} を使用します。"
    GIT_CLONE_CMD+=" --reference ${REFERENCE_REPO_PATH} --dissociate"
fi
GIT_CLONE_CMD+=" ${REPOSITORY_URL} ${ACTUAL_GIT_REPO_PATH_ON_HOST}"
eval "${GIT_CLONE_CMD}"
if [ $? -ne 0 ] || [ ! -d "${ACTUAL_GIT_REPO_PATH_ON_HOST}" ]; then
    echo "エラー: リポジトリ ${REPOSITORY_URL} のクローンに失敗しました。"
    # cd "${PROJECT_ROOT_DIR}" # 元のディレクトリに戻るか、あるいはここで終了
    rm -rf "${HOST_TASK_WORK_DIR}"
    exit 1
fi
cd "${ACTUAL_GIT_REPO_PATH_ON_HOST}" || { echo "エラー: ${ACTUAL_GIT_REPO_PATH_ON_HOST} へのcdに失敗"; rm -rf "${HOST_TASK_WORK_DIR}"; exit 1; }
if ! git cat-file -e "${COMMIT_ID}"^{commit} 2>/dev/null; then
    echo "Commit ${COMMIT_ID} not found locally, attempting to fetch..."
    git fetch --quiet origin "${COMMIT_ID}" || git fetch --quiet
    if ! git cat-file -e "${COMMIT_ID}"^{commit} 2>/dev/null; then
        echo "エラー: コミット ${COMMIT_ID} をfetch後も見つけられません。"
        # cd "${PROJECT_ROOT_DIR}"
        rm -rf "${HOST_TASK_WORK_DIR}"
        exit 1
    fi
fi
git checkout --quiet "${COMMIT_ID}"
if [ $? -ne 0 ]; then
    echo "エラー: コミット ${COMMIT_ID} のチェックアウトに失敗しました。"
    # cd "${PROJECT_ROOT_DIR}"
    rm -rf "${HOST_TASK_WORK_DIR}"
    exit 1
fi
echo "リポジトリの準備が完了しました。"
# cd "${PROJECT_ROOT_DIR}" # sbatch実行時のカレントディレクトリに戻る (任意)
# --- Gitリポジトリの準備完了 ---


# --- Singularityコンテナの実行 ---
echo "Singularityコンテナ (${SINGULARITY_IMAGE_PATH}) を実行します..."

SINGULARITY_EXEC_OPTS=""
if [ -n "${CUDA_VISIBLE_DEVICES}" ]; then # GPU利用時
    SINGULARITY_EXEC_OPTS+="--nv "
fi

SINGULARITY_EXEC_OPTS+="--bind ${ACTUAL_GIT_REPO_PATH_ON_HOST}:${CONTAINER_PROJECT_MOUNT_POINT}:ro "
SINGULARITY_EXEC_OPTS+="--bind ${HOST_TASK_FINAL_OUTPUT_DIR}:${CONTAINER_OUTPUT_MOUNT_POINT}:rw "
SINGULARITY_EXEC_OPTS+="--bind /etc/passwd:/etc/passwd:ro --bind /etc/group:/etc/group:ro "

CMD_ARGS=(
    "${CONTAINER_PROJECT_MOUNT_POINT}"
    "${TARGET_FILE_IN_REPO}"
    "${CONTAINER_OUTPUT_MOUNT_POINT}"
    "${CONTAINER_JAVA_HOME}"
    "${CONTAINER_APP_ROOT}"
)

echo "実行コマンド: singularity exec ${SINGULARITY_EXEC_OPTS} ${SINGULARITY_IMAGE_PATH} bash ${CONTAINER_APP_SCRIPT_PATH} ${CMD_ARGS[*]}"

singularity exec ${SINGULARITY_EXEC_OPTS} "${SINGULARITY_IMAGE_PATH}" \
    bash "${CONTAINER_APP_SCRIPT_PATH}" "${CMD_ARGS[@]}"

SINGULARITY_EXIT_CODE=$?
echo "Singularityコンテナの実行が終了しました。終了コード: ${SINGULARITY_EXIT_CODE}"
# --- Singularityコンテナの実行完了 ---


# --- クリーンアップ ---
echo "一時作業ディレクトリ ${HOST_TASK_WORK_DIR} を削除しています..."
rm -rf "${HOST_TASK_WORK_DIR}"
echo "クリーンアップ完了。"
# --- クリーンアップ完了 ---

if [ ${SINGULARITY_EXIT_CODE} -ne 0 ]; then
    echo "エラー: タスク ${SLURM_ARRAY_TASK_ID} (Output ID: ${OUTPUT_IDENTIFIER}) は失敗しました。終了コード: ${SINGULARITY_EXIT_CODE}"
    exit ${SINGULARITY_EXIT_CODE}
fi

echo "タスク ${SLURM_ARRAY_TASK_ID} (Output ID: ${OUTPUT_IDENTIFIER}) は正常に完了しました。"
exit 0
