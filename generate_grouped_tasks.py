# generate_grouped_tasks.py (骨子)
import csv
from itertools import groupby
from pathlib import Path

SORTED_TASKS_FILE = 'tasks_sorted.list' # ステップ1で生成したソート済みファイル
GROUPED_TASKS_OUTPUT_FILE = 'grouped_tasks.list' # 新しいタスクリスト

# tasks.listの列のインデックスを定義 (実際のファイルに合わせて調整)
# 例: 0:project_name, 1:commit_id, 2:target_file, 3:output_id, 4:repo_url, 5:ref_path
IDX_PROJECT_NAME = 0
IDX_COMMIT_ID = 1
IDX_REPO_URL = 4 # ソート済みtasks.listのrepository_urlが含まれる列
IDX_REF_PATH = 5 # ソート済みtasks.listのreference_repo_pathが含まれる列

def create_grouped_tasks():
    with open(SORTED_TASKS_FILE, 'r', newline='', encoding='utf-8') as infile, \
         open(GROUPED_TASKS_OUTPUT_FILE, 'w', newline='', encoding='utf-8') as outfile:
        
        reader = csv.reader(infile) # カンマ区切りを想定
        writer = csv.writer(outfile)
        
        current_line_number = 0
        for key, group in groupby(reader, key=lambda x: (x[IDX_PROJECT_NAME], x[IDX_COMMIT_ID])):
            project_name, commit_id = key
            group_lines = list(group)
            num_lines_in_group = len(group_lines)
            
            if num_lines_in_group == 0:
                continue

            # グループの最初の行からリポジトリ情報などを取得
            first_line_of_group = group_lines[0]
            repo_url = first_line_of_group[IDX_REPO_URL]
            ref_path = first_line_of_group[IDX_REF_PATH]
            
            # このグループが元のソート済みtasks.listの何行目(1始まり)から何行分か
            original_start_line = current_line_number + 1 
            
            writer.writerow([project_name, commit_id, repo_url, ref_path,
                             original_start_line, num_lines_in_group])
            
            current_line_number += num_lines_in_group
    print(f"グループ化されたタスクリスト '{GROUPED_TASKS_OUTPUT_FILE}' を生成しました。")

if __name__ == '__main__':
    # (出力ディレクトリ作成処理など、必要に応じて追加)
    Path(GROUPED_TASKS_OUTPUT_FILE).parent.mkdir(parents=True, exist_ok=True)
    create_grouped_tasks()
