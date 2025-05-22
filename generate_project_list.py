#!/usr/bin/env python3
import csv
from pathlib import Path

# --- 設定項目 ---
# 元の (ソート済み) tasks.list または refactorings_initial.csv
ORIGINAL_DETAILED_TASKS_FILE = 'tasks_sorted.list' # ★実際のファイル名に合わせてください★
                                                 # このファイルには project_name, repository_url, reference_repo_path が含まれる想定
                                                 # 列のインデックスや名前は以下で調整
IDX_PROJECT_NAME = 0
IDX_REPOSITORY_URL = 4 # tasks_sorted.list の repository_url が含まれる列インデックス
IDX_REFERENCE_REPO = 5 # tasks_sorted.list の reference_repo_path が含まれる列インデックス

# 出力するプロジェクトリストファイル
PROJECT_LIST_OUTPUT_FILE = 'project_list.txt' # ★出力先★
# --- 設定項目ここまで ---

def create_project_list():
    projects_info = {} # {project_name: {'url': ..., 'ref_path': ...}}

    input_file = Path(ORIGINAL_DETAILED_TASKS_FILE)
    if not input_file.is_file():
        print(f"エラー: 入力ファイル '{ORIGINAL_DETAILED_TASKS_FILE}' ('{input_file.resolve()}') が見つかりません。")
        return

    try:
        with open(input_file, 'r', newline='', encoding='utf-8') as csvfile:
            reader = csv.reader(csvfile) # カンマ区切りを想定
            # header = next(reader, None) # ヘッダー行があればスキップ (任意)
            
            for row in reader:
                if not row: continue # 空行対策
                try:
                    project_name = row[IDX_PROJECT_NAME].strip()
                    repo_url = row[IDX_REPOSITORY_URL].strip()
                    ref_path = row[IDX_REFERENCE_REPO].strip() if len(row) > IDX_REFERENCE_REPO else ''

                    if project_name not in projects_info:
                        projects_info[project_name] = {'url': repo_url, 'ref_path': ref_path}
                except IndexError:
                    print(f"警告: 行 '{','.join(row)}' の列数が不足しています。スキップします。")
                    continue
        
        output_file = Path(PROJECT_LIST_OUTPUT_FILE)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w', encoding='utf-8') as outfile:
            writer = csv.writer(outfile)
            # ヘッダーを書き出す場合 (任意)
            # writer.writerow(['project_name_owner_repo', 'repository_url', 'reference_repo_path'])
            for project_name, info in projects_info.items():
                writer.writerow([project_name, info['url'], info['ref_path']])
        
        print(f"プロジェクトリスト '{output_file.resolve()}' を生成しました。ユニークなプロジェクト数: {len(projects_info)}")

    except Exception as e:
        print(f"エラー: プロジェクトリスト生成中にエラーが発生しました: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    print("--- project_list.txt 生成スクリプト開始 ---")
    create_project_list()
    print("--- project_list.txt 生成スクリプト終了 ---")
