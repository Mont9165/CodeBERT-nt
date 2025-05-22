#!/bin/bash
# このスクリプトはプロジェクトルートディレクトリから実行することを想定しています。

PROJECT_ROOT="/work/kosei-ho/CodeBERT_naruralness/CodeBERT-nt"
# 分割されたタスクファイルが格納されているディレクトリ
TASK_PART_DIR="${PROJECT_ROOT}/data/input" # ★tasks_part_*.list ファイルがある正しいパス★

# Slurmジョブ投入スクリプトのパス
SBATCH_SCRIPT_PATH="${PROJECT_ROOT}/cluster_script/submit_sbatch_job.sh"

LOG_DIR="${PROJECT_ROOT}/logs"
ERROR_DIR="${PROJECT_ROOT}/error" # もし submit_sbatch_job.sh でエラーログを別ディレクトリに指定している場合
SUBMITTED_BATCHES_LOG="${PROJECT_ROOT}/logs/submitted_batches.log"

mkdir -p "${LOG_DIR}" "${ERROR_DIR}"
touch "${SUBMITTED_BATCHES_LOG}"

echo "分割タスクファイルの検索場所: ${TASK_PART_DIR}"
if [ ! -d "${TASK_PART_DIR}" ]; then
    echo "エラー: 分割タスクファイル用ディレクトリが見つかりません: ${TASK_PART_DIR}"
    exit 1
fi

# 分割された各タスクファイルをループ処理
declare -A submitted_files_map
while IFS= read -r line; do
    # ログの形式を "Submitted JobID: <id> for TaskFile: <filepath>" と仮定
    if [[ "$line" == *"Successfully submitted batch for TaskFile: "* ]]; then
        submitted_file_path=$(echo "$line" | sed -n 's/.*Successfully submitted batch for TaskFile: \([^ ]*\).*/\1/p')
        if [ -n "$submitted_file_path" ]; then
            submitted_files_map["$submitted_file_path"]=1
            # echo "DEBUG: Marked as submitted from log: $submitted_file_path"
        fi
    fi
done < "${SUBMITTED_BATCHES_LOG}"


for task_file_full_path in $(ls -v "${TASK_PART_DIR}"/tasks_part_*.list); do # -vで自然順ソート
    if [ ! -f "${task_file_full_path}" ]; then
        echo "警告: ${task_file_full_path} が見つからないか、ファイルではありません。スキップします。"
        continue
    fi

    # ★このタスクファイルが既に投入済みか確認★
    if [[ ${submitted_files_map["${task_file_full_path}"]} ]]; then
        echo "情報: ${task_file_full_path} は既に投入済みです。スキップします。"
        continue
    fi

    num_lines=$(wc -l < "${task_file_full_path}")
    if [ "${num_lines}" -eq 0 ]; then
        echo "警告: ${task_file_full_path} は空です。スキップします。"
        continue
    fi

    array_max_index=$((num_lines - 1))
    task_file_basename=$(basename "${task_file_full_path}")

    echo ""
    echo "-------------------------------------------------------------------"
    echo "Slurmジョブを投入します: ${task_file_basename} (フルパス: ${task_file_full_path})"
    echo "  このパーツのタスク数: ${num_lines}"
    echo "  Slurm --array 指定: 0-${array_max_index}"
    echo "-------------------------------------------------------------------"

    submission_output=$(sbatch \
        --job-name="cb_nt_${task_file_basename}" \
        --export=ALL,MY_CURRENT_TASK_LIST_FILE="${task_file_full_path}" \
        --array="0-${array_max_index}" \
        "${SBATCH_SCRIPT_PATH}")

    sbatch_exit_code=$?
    submitted_job_id=$(echo "${submission_output}" | awk '{print $4}') # "Submitted batch job XXXXX" からID取得

    if [ ${sbatch_exit_code} -eq 0 ] && [ -n "${submitted_job_id}" ]; then
        echo "正常に投入されました: ${task_file_basename} (ジョブID: ${submitted_job_id})"
        # ★投入成功を記録★
        echo "Successfully submitted batch for TaskFile: ${task_file_full_path} with JobID: ${submitted_job_id} on $(date)" >> "${SUBMITTED_BATCHES_LOG}"

        # 完了を待つロジック (方法1: 簡易ポーリング) - 必要であればコメント解除して調整
        # echo "ジョブ ${submitted_job_id} の完了を待っています..."
        # while true; do
        #     job_status_count=$(squeue -j "${submitted_job_id}" -h -o "%A" | wc -l)
        #     if [ "${job_status_count}" -eq 0 ]; then
        #         echo "ジョブ ${submitted_job_id} は完了したか、キューからなくなりました。"
        #         # sacctで最終状態を確認した方がより確実
        #         # final_status_output=$(sacct -j "${submitted_job_id}" --format=JobID,JobName,State,ExitCode --noheader | head -n 1)
        #         # echo "ジョブ ${submitted_job_id} の最終情報: ${final_status_output}"
        #         break
        #     else
        #         echo -n "." # 進捗表示
        #         sleep 30 # 30秒待機して再確認 (間隔は調整)
        #     fi
        # done
        # echo "ジョブ ${submitted_job_id} の待機を終了しました。"

    else
        echo "エラー: ${task_file_basename} のsbatch投入に失敗しました。終了コード: ${sbatch_exit_code}。"
        echo "出力: ${submission_output}"
        # エラーが発生した場合、このスクリプトを中断するかどうか
        # exit 1 # 中断する場合
    fi
    echo "-------------------------------------------------------------------"

    if [ "${sbatch_exit_code}" -eq 0 ] && [ -n "${submitted_job_id}" ]; then
      if [ "${current_offset}" -lt "${TOTAL_LINES_IN_TASK_FILE}" ]; then # この条件はループ構造が変わったので不要かも
          echo "次のパーツ投入まで100秒待機します..." # 投入間隔
          sleep 100
      fi
    fi
done

echo ""
echo "全ての(未投入だった)分割タスクファイルのジョブが投入されました。"
