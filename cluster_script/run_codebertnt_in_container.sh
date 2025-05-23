#!/bin/bash
set -e

# --- スクリプト引数 ---
ARG_PROJECT_REPO_IN_CONTAINER="$1"  # マウントされたリポジトリパス (この中でgit checkout)
ARG_ORIGINAL_TASKS_LIST_PATH="$2" # マウントされた元のtasks_sorted.list
ARG_CURRENT_PROJECT_NAME="$3"     # 現在処理中のプロジェクト名
ARG_PROJECT_OUTPUT_BASE_DIR="$4"  # このプロジェクトの出力ベースディレクトリ
ARG_JAVA_HOME="$5"
APP_ROOT="${6:-/app}"

# ... (PYTHON_EXECUTABLE, CODEBERT_RUNNER_FULL_PATH などは前回同様) ...
PYTHON_EXECUTABLE="python3"
CODEBERT_RUNNER_SCRIPT_RELATIVE_PATH="codebertnt/codebertnt_runner.py" 
CODEBERT_RUNNER_FULL_PATH="${APP_ROOT}/${CODEBERT_RUNNER_SCRIPT_RELATIVE_PATH}"

echo "--- Project Task Started in Container (Project: ${ARG_CURRENT_PROJECT_NAME}) ---"
# ... (基本的なログ)

# 1. 元のタスクリストから現在のプロジェクトのタスクのみをフィルタリング
#    awk を使うと効率的 (project_nameが第1列と仮定)
FILTERED_PROJECT_TASKS_FILE="/tmp/filtered_tasks_for_${ARG_CURRENT_PROJECT_NAME//\//_}.list"
awk -F, -v project="${ARG_CURRENT_PROJECT_NAME}" '$1 == project {print}' "${ARG_ORIGINAL_TASKS_LIST_PATH}" > "${FILTERED_PROJECT_TASKS_FILE}"

if [ ! -s "${FILTERED_PROJECT_TASKS_FILE}" ]; then
    echo "情報: プロジェクト ${ARG_CURRENT_PROJECT_NAME} に該当するタスクが見つかりません。"
    exit 0
fi
echo "プロジェクト ${ARG_CURRENT_PROJECT_NAME} のタスクを抽出しました。($(wc -l < "${FILTERED_PROJECT_TASKS_FILE}") 件)"

# 2. フィルタリングされたタスクをコミットIDでソート (重要: これによりコミット切り替えが最小限になる)
SORTED_FILTERED_TASKS_FILE="/tmp/sorted_filtered_tasks_for_${ARG_CURRENT_PROJECT_NAME//\//_}.list"
# tasks_sorted.listの列構成: project,commit,file,output_id,repo_url,ref_path (コミットIDが第2列と仮定)
sort -t, -k2,2 "${FILTERED_PROJECT_TASKS_FILE}" > "${SORTED_FILTERED_TASKS_FILE}"

# 3. コミットごとにループし、その中のファイルを処理
current_checked_out_commit=""
while IFS=',' read -r _PROJECT_NAME_ITEM COMMIT_ID_ITEM TARGET_FILE_IN_REPO_ITEM \
                        OUTPUT_IDENTIFIER_ITEM _REPO_URL_ITEM _REF_PATH_ITEM; do
    
    echo ""
    echo "  Processing item - Commit: ${COMMIT_ID_ITEM}, File: ${TARGET_FILE_IN_REPO_ITEM}"

    # 必要であればコミットをチェックアウト (現在のコミットと異なれば)
    if [ "${current_checked_out_commit}" != "${COMMIT_ID_ITEM}" ]; then
        echo "    Checking out commit ${COMMIT_ID_ITEM} in ${ARG_PROJECT_REPO_IN_CONTAINER}..."
        cd "${ARG_PROJECT_REPO_IN_CONTAINER}" || { echo "エラー: リポジトリへのcd失敗"; continue; } # エラーなら次のアイテムへ
        
        # git fetch が必要になる場合も考慮 (ただし、Slurmスクリプト側でクローン時に全履歴取得を推奨)
        if ! git cat-file -e "${COMMIT_ID_ITEM}"^{commit} 2>/dev/null; then
            echo "    Commit ${COMMIT_ID_ITEM} not found, attempting fetch..."
            git fetch --quiet origin "${COMMIT_ID_ITEM}" || git fetch --quiet origin --tags || git fetch --quiet
            if ! git cat-file -e "${COMMIT_ID_ITEM}"^{commit} 2>/dev/null; then
                echo "    エラー: コミット ${COMMIT_ID_ITEM} fetch後も発見できず。スキップします。"
                continue
            fi
        fi
        git checkout --quiet "${COMMIT_ID_ITEM}"
        if [ $? -ne 0 ]; then
            echo "    エラー: コミット ${COMMIT_ID_ITEM} のチェックアウト失敗。スキップします。"
            continue
        fi
        current_checked_out_commit="${COMMIT_ID_ITEM}"
        echo "    Commit ${COMMIT_ID_ITEM} checked out."
    fi
    
    # 各アイテムの出力ディレクトリ (プロジェクトのベース出力ディレクトリの下に)
    ITEM_SPECIFIC_OUTPUT_DIR="${ARG_PROJECT_OUTPUT_BASE_DIR}/${OUTPUT_IDENTIFIER_ITEM}"
    mkdir -p "${ITEM_SPECIFIC_OUTPUT_DIR}"
    echo "    Output for this item: ${ITEM_SPECIFIC_OUTPUT_DIR}"

    # ターゲットファイルの存在確認 (チェックアウト後のリポジトリ内で)
    TARGET_FILE_FULL_PATH_IN_REPO_ITEM="${ARG_PROJECT_REPO_IN_CONTAINER}/${TARGET_FILE_IN_REPO_ITEM}"
    if [ ! -f "${TARGET_FILE_FULL_PATH_IN_REPO_ITEM}" ]; then
        echo "    エラー: ターゲットファイルが見つかりません: ${TARGET_FILE_FULL_PATH_IN_REPO_ITEM} (コミット ${COMMIT_ID_ITEM} 内)"
        continue
    fi

    # codebertnt_runner.py を実行
    echo "    Executing codebertnt_runner.py for ${TARGET_FILE_IN_REPO_ITEM}..."
    set -x
    "${PYTHON_EXECUTABLE}" "${CODEBERT_RUNNER_FULL_PATH}" \
        -repo_path "${ARG_PROJECT_REPO_IN_CONTAINER}" \
        -target_classes "${TARGET_FILE_IN_REPO_ITEM}" \
        -java_home "${ARG_JAVA_HOME}" \
        -output_dir "${ITEM_SPECIFIC_OUTPUT_DIR}" \
        -force_reload "False" \
	-cosine "False" \
    RUNNER_EXIT_CODE=$?
    set +x
    
    if [ ${RUNNER_EXIT_CODE} -ne 0 ]; then
        echo "    警告: アイテム ${OUTPUT_IDENTIFIER_ITEM} の処理でエラー (codebertnt_runner.py 終了コード ${RUNNER_EXIT_CODE})"
    else
        echo "    アイテム ${OUTPUT_IDENTIFIER_ITEM} 処理完了。"
    fi

done < "${SORTED_FILTERED_TASKS_FILE}" # ソート済みの、このプロジェクト専用のタスクリストを読む

rm -f "${FILTERED_PROJECT_TASKS_FILE}" "${SORTED_FILTERED_TASKS_FILE}" # 一時ファイル削除
echo "--- Project Task Finished in Container (Project: ${ARG_CURRENT_PROJECT_NAME}) ---"
exit 0 # プロジェクト全体の処理としては正常終了 (個々のアイテムの成否はログで)
