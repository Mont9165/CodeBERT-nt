#!/bin/bash

# --- SBATCH Directives ---
#SBATCH --job-name=codebert_nt_project_batch # ジョブ名
#SBATCH --output=logs/project_output_%A_%a.out # 標準出力ログの絶対パス
#SBATCH --error=error/project_error_%A_%a.err  # 標準エラーログの絶対パス
#SBATCH --array=0-567%70 # ★重要★ project_list.txt の (総行数 - 1) に必ず調整してください (例: 460プロジェクトなら0-459)
#SBATCH --time=2-04:00:00      # 1プロジェクトあたりの最大実行時間 - ★プロジェクト内のタスク数に応じて要調整★
#SBATCH --partition=ocigpu1a10_long  # ★NAISTクラスタの適切な本番用パーティション名に変更してください★
#SBATCH --ntasks=1             # 1配列タスクあたり1つのMPIタスク (通常このまま)
#SBATCH --cpus-per-task=2      # ★1プロジェクト処理に必要なCPUコア数。コンテナ内スクリプトの並列度も考慮して調整★
#SBATCH --mem=32G              # ★1プロジェクト処理に必要なメモリ量。プロジェクト内の最大ファイル数やサイズを考慮して調整★
##SBATCH --gres=gpu:1          # GPUを使用する場合にコメント解除し、必要なGPU数と種類を指定

# --- Configuration ---
# このセクションのパスや設定を必ずご自身の環境に合わせてください。

# プロジェクトのルートディレクトリ (固定の絶対パスで指定)
PROJECT_ROOT_DIR="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt"

# Singularityイメージファイルの絶対パス
SINGULARITY_IMAGE_PATH="${PROJECT_ROOT_DIR}/codebert-nt.sif"

# 各Slurmタスクが処理するプロジェクトの情報が書かれたファイル (プロジェクト名, リポジトリURL, 参照パス)
PROJECT_LIST_FILE="${PROJECT_ROOT_DIR}/data/processed/project_list.txt" # ★このファイルが存在することを確認★

# コンテナ内で処理される個々のタスク情報が書かれた、ソート済みの完全なリスト
# (project_name, commit_id, target_file, output_id, repo_url, ref_path の形式を想定)
ORIGINAL_SORTED_TASKS_FILE_ON_HOST="${PROJECT_ROOT_DIR}/tasks_sorted.list" # ★このファイルが存在することを確認★

# 各プロジェクトの一時作業(Gitクローン)ディレクトリのベース
HOST_TEMP_WORK_BASE_DIR="/work/kosei-ho/scratch/codebert_project_work_final" # ★必要なら名前変更★

# 各プロジェクトの最終出力ディレクトリのベース
HOST_FINAL_OUTPUT_BASE_DIR="${PROJECT_ROOT_DIR}/results_project_batch_final" # ★必要なら名前変更★

HOST_APP_SCRIPT_PATH="${PROJECT_ROOT_DIR}/cluster_script/run_codebertnt_in_container.sh" 

# --- コンテナ内パス設定 ---
CONTAINER_PROJECT_REPO_MOUNT_POINT="/mnt/repo"  # プロジェクトのGitリポジトリのマウント先
CONTAINER_ORIGINAL_TASKS_LIST_MOUNT_POINT="/mnt/original_sorted_tasks.list" # 元のタスクリストのマウント先
CONTAINER_OUTPUT_BASE_MOUNT_POINT="/mnt/output_project_base" # このプロジェクトの出力ベース
CONTAINER_APP_SCRIPT_MOUNT_POINT="/mnt/cluster_script/run_codebertnt_in_container.sh"

CONTAINER_APP_SCRIPT_PATH="/app/run_codebertnt_in_container.sh" # Singularityイメージ内の実行スクリプト
CONTAINER_JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64" # ★Singularityイメージ内の実際のJDKパスに合わせる★
CONTAINER_APP_ROOT="/app" # Singularityイメージ内のアプリケーションルート
# --- End Configuration ---

# --- 事前準備 ---
echo "--- SLURM Project Job Start (SlurmTaskID ${SLURM_ARRAY_TASK_ID}) ---"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"
echo "SLURM_ARRAY_JOB_ID: ${SLURM_ARRAY_JOB_ID}" # SLURM_ARRAY_JOB_ID はジョブ配列全体のID
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "Initial WorkDir (where sbatch was run, or Slurm's default): $(pwd)"
echo "PROJECT_ROOT_DIR (Configured): ${PROJECT_ROOT_DIR}"
echo "SINGULARITY_IMAGE_PATH: ${SINGULARITY_IMAGE_PATH}"
echo "PROJECT_LIST_FILE: ${PROJECT_LIST_FILE}"
echo "ORIGINAL_SORTED_TASKS_FILE_ON_HOST: ${ORIGINAL_SORTED_TASKS_FILE_ON_HOST}"
echo "HOST_TEMP_WORK_BASE_DIR: ${HOST_TEMP_WORK_BASE_DIR}"
echo "HOST_FINAL_OUTPUT_BASE_DIR: ${HOST_FINAL_OUTPUT_BASE_DIR}"
echo "----------------------------------------------------"

# ログディレクトリ、出力ベースディレクトリ、一時作業ベースディレクトリの作成
mkdir -p "${PROJECT_ROOT_DIR}/logs" \
         "${HOST_TEMP_WORK_BASE_DIR}" \
         "${HOST_FINAL_OUTPUT_BASE_DIR}"
echo "Required host directories checked/created."

# Singularityモジュールのロード
echo "Loading Singularity module..."
module purge
module load singularity/3.8.7 # ★NAISTクラスタの利用可能なSingularityバージョンに合わせてください★
echo "Singularity module load attempt finished."
echo "PATH after module load: $PATH"
echo "Which singularity: $(which singularity)"
singularity --version || { echo "エラー: Singularityコマンドが利用できません。モジュールロード失敗またはパスの問題の可能性。"; exit 1; }
echo "---"

# --- タスク処理 ---
# ファイル存在チェック
if [ ! -f "${PROJECT_LIST_FILE}" ]; then
    echo "エラー: プロジェクトリストファイル ${PROJECT_LIST_FILE} が見つかりません。"
    exit 1
fi
if [ ! -f "${ORIGINAL_SORTED_TASKS_FILE_ON_HOST}" ]; then
    echo "エラー: 元のソート済みタスクリストファイル ${ORIGINAL_SORTED_TASKS_FILE_ON_HOST} が見つかりません。"
    exit 1
fi
echo "プロジェクトリストファイル: ${PROJECT_LIST_FILE}"
echo "元タスクリストファイル: ${ORIGINAL_SORTED_TASKS_FILE_ON_HOST}"

# project_list.txt から現在のSlurmタスクが担当するプロジェクト情報を読み込む
# フォーマット想定: project_name_owner_repo,repository_url,reference_repo_path_or_empty
CURRENT_PROJECT_INFO_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "${PROJECT_LIST_FILE}")

if [ -z "${CURRENT_PROJECT_INFO_LINE}" ]; then
    echo "エラー: プロジェクトタスクID ${SLURM_ARRAY_TASK_ID} に対応する行が ${PROJECT_LIST_FILE} に見つかりません。"
    exit 1
fi

IFS=',' read -r PROJECT_NAME_OWNER_REPO REPOSITORY_URL REFERENCE_REPO_PATH <<< "${CURRENT_PROJECT_INFO_LINE}"

echo "--- Current Project Task (SlurmTaskID: ${SLURM_ARRAY_TASK_ID}) ---"
echo "Project Name (owner_reponame): ${PROJECT_NAME_OWNER_REPO}"
echo "Repository URL: ${REPOSITORY_URL}"
echo "Reference Repo Path: ${REFERENCE_REPO_PATH:-N/A}" # 空の場合は N/A と表示
echo "-------------------------------------------------"

# --- このプロジェクト固有のディレクトリ設定 ---
# このプロジェクトの一時作業ディレクトリ (Gitクローン用)
# ディレクトリ名にジョブID全体とタスクIDを含め、プロジェクト名も入れることでユニーク性を高める
HOST_PROJECT_WORK_DIR="${HOST_TEMP_WORK_BASE_DIR}/${SLURM_ARRAY_JOB_ID}_proj${SLURM_ARRAY_TASK_ID}_${PROJECT_NAME_OWNER_REPO//\//_}"
mkdir -p "${HOST_PROJECT_WORK_DIR}"
echo "Host project work directory: ${HOST_PROJECT_WORK_DIR}"

# このプロジェクトの最終出力ベースディレクトリ
# コンテナ内スクリプトが、この下に個々のコミットやファイルの出力サブディレクトリを作成する
HOST_PROJECT_FINAL_OUTPUT_DIR="${HOST_FINAL_OUTPUT_BASE_DIR}/${PROJECT_NAME_OWNER_REPO//\//_}"
mkdir -p "${HOST_PROJECT_FINAL_OUTPUT_DIR}"
echo "Host project final output directory: ${HOST_PROJECT_FINAL_OUTPUT_DIR}"

# --- Gitリポジトリの準備 (プロジェクトごとに1回) ---
echo "リポジトリ (${REPOSITORY_URL}) を ${HOST_PROJECT_WORK_DIR} に準備しています..."
SBATCH_SUBMIT_DIR_CAPTURE="${SLURM_SUBMIT_DIR:-$(pwd)}" # ジョブ投入時のディレクトリをSlurm変数から取得、なければ現在のpwd

# Gitクローンは、プロジェクト固有の一時作業ディレクトリ(ACTUAL_GIT_REPO_PATH_ON_HOST)に対して行う
# まず、クローン先の親ディレクトリに移動
cd "${HOST_PROJECT_WORK_DIR}" || { echo "エラー: 作業ディレクトリ ${HOST_PROJECT_WORK_DIR} に移動できませんでした。"; exit 1; }
TEMP_GIT_DIR_NAME=$(basename "${REPOSITORY_URL}" .git) # リポジトリ名を取得 (例: solo)
ACTUAL_GIT_REPO_PATH_ON_HOST="${HOST_PROJECT_WORK_DIR}/${TEMP_GIT_DIR_NAME}" # クローンされるリポジトリのフルパス

# 既に同名ディレクトリがあれば削除 (前回の残骸や途中失敗の場合を考慮)
if [ -d "${ACTUAL_GIT_REPO_PATH_ON_HOST}" ]; then
    echo "警告: 既存のディレクトリ ${ACTUAL_GIT_REPO_PATH_ON_HOST} を削除します。"
    rm -rf "${ACTUAL_GIT_REPO_PATH_ON_HOST}"
fi

GIT_CLONE_CMD="git clone --quiet"
if [ -n "${REFERENCE_REPO_PATH}" ] && [ -d "${REFERENCE_REPO_PATH}" ]; then
    echo "参照リポジトリ ${REFERENCE_REPO_PATH} を使用します。"
    GIT_CLONE_CMD+=" --reference ${REFERENCE_REPO_PATH} --dissociate"
fi
GIT_CLONE_CMD+=" ${REPOSITORY_URL} ${ACTUAL_GIT_REPO_PATH_ON_HOST}" # クローン先を明示的に指定
echo "Executing Git Clone: ${GIT_CLONE_CMD}"
eval "${GIT_CLONE_CMD}"

if [ $? -ne 0 ] || [ ! -d "${ACTUAL_GIT_REPO_PATH_ON_HOST}" ]; then
    echo "エラー: リポジトリ ${REPOSITORY_URL} のクローンに失敗しました (場所: ${ACTUAL_GIT_REPO_PATH_ON_HOST})。"
    cd "${SBATCH_SUBMIT_DIR_CAPTURE}" # 元のディレクトリに戻る
    rm -rf "${HOST_PROJECT_WORK_DIR}" # 作成した一時ディレクトリを削除
    exit 1
fi
echo "プロジェクトリポジトリの準備完了: ${ACTUAL_GIT_REPO_PATH_ON_HOST}"
# この段階では特定のコミットへのチェックアウトは行わない。コンテナ内スクリプトが行う。
cd "${SBATCH_SUBMIT_DIR_CAPTURE}" # sbatch実行時のカレントディレクトリに戻る
# --- Gitリポジトリ準備完了 ---


# --- Singularityコンテナの実行 ---
echo "Singularityコンテナ (${SINGULARITY_IMAGE_PATH}) を実行します (プロジェクト: ${PROJECT_NAME_OWNER_REPO})..."
SINGULARITY_EXEC_OPTS=""
# GPUを使用する場合のオプション (SBATCHディレクティブで --gres=gpu を指定した場合)
if [ -n "${CUDA_VISIBLE_DEVICES}" ]; then
    SINGULARITY_EXEC_OPTS+="--nv "
fi

# バインドマウントの設定
SINGULARITY_EXEC_OPTS+="--bind ${ACTUAL_GIT_REPO_PATH_ON_HOST}:${CONTAINER_PROJECT_REPO_MOUNT_POINT}:rw " # ★コンテナ内でgit checkoutするため :rw★
SINGULARITY_EXEC_OPTS+="--bind ${HOST_PROJECT_FINAL_OUTPUT_DIR}:${CONTAINER_OUTPUT_BASE_MOUNT_POINT}:rw "
SINGULARITY_EXEC_OPTS+="--bind ${ORIGINAL_SORTED_TASKS_FILE_ON_HOST}:${CONTAINER_ORIGINAL_TASKS_LIST_MOUNT_POINT}:ro "
SINGULARITY_EXEC_OPTS+="--bind /etc/passwd:/etc/passwd:ro --bind /etc/group:/group:ro " # /etc/group も :ro
SINGULARITY_EXEC_OPTS+="--bind ${HOST_APP_SCRIPT_PATH}:${CONTAINER_APP_SCRIPT_MOUNT_POINT}:ro " 


# コンテナ内実行スクリプトに渡す引数
CMD_ARGS=(
    "${CONTAINER_PROJECT_REPO_MOUNT_POINT}"         # $1: マウントされたリポジトリパス (この中でgit checkoutする)
    "${CONTAINER_ORIGINAL_TASKS_LIST_MOUNT_POINT}"   # $2: マウントされた元のtasks_sorted.list
    "${PROJECT_NAME_OWNER_REPO}"                     # $3: 現在処理中のプロジェクト名 (コンテナ内スクリプトがフィルタリングに使う)
    "${CONTAINER_OUTPUT_BASE_MOUNT_POINT}"          # $4: このプロジェクトの出力ベースディレクトリ
    "${CONTAINER_JAVA_HOME}"                         # $5
    "${CONTAINER_APP_ROOT}"                          # $6
)

echo "実行コマンド: singularity exec ${SINGULARITY_EXEC_OPTS} ${SINGULARITY_IMAGE_PATH} bash ${CONTAINER_APP_SCRIPT_PATH} ${CMD_ARGS[*]}"

singularity exec ${SINGULARITY_EXEC_OPTS} "${SINGULARITY_IMAGE_PATH}" \
    bash "${CONTAINER_APP_SCRIPT_MOUNT_POINT}" "${CMD_ARGS[@]}"

SINGULARITY_EXIT_CODE=$?
echo "Singularityコンテナの実行が終了しました。終了コード: ${SINGULARITY_EXIT_CODE}"
# --- Singularityコンテナの実行完了 ---


# --- クリーンアップ ---
echo "一時作業ディレクトリ ${HOST_PROJECT_WORK_DIR} を削除しています..."
# rm -rf "${HOST_PROJECT_WORK_DIR}" # ★テストが完全に成功し、結果も確認できるまではコメントアウト推奨★
echo "クリーンアップ完了 (テスト中は削除スキップの可能性あり)。"
# --- クリーンアップ完了 ---

if [ ${SINGULARITY_EXIT_CODE} -ne 0 ]; then
    echo "エラー: プロジェクトタスク ${SLURM_ARRAY_TASK_ID} (Project: ${PROJECT_NAME_OWNER_REPO}) は失敗しました。終了コード: ${SINGULARITY_EXIT_CODE}"
    exit ${SINGULARITY_EXIT_CODE}
fi

echo "プロジェクトタスク ${SLURM_ARRAY_TASK_ID} (Project: ${PROJECT_NAME_OWNER_REPO}) は正常に完了しました。"
exit 0
