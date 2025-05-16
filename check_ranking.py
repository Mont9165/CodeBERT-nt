import gzip
import pickle
import pandas as pd

# pandasの表示設定を変更
pd.set_option('display.max_rows', None)  # 行数の制限を解除
pd.set_option('display.max_columns', None)  # 列数の制限を解除
pd.set_option('display.width', None)  # 表示幅の制限を解除
pd.set_option('display.max_colwidth', None)  # 列の幅の制限を解除

# 結果ファイルのパス
result_file = "test/res/output/cbnt_output_dir/DummyProject_min_conf_order/DummyProject_cbnt.pickle"

# pickleファイルを読み込む（バージョン4を指定）
with gzip.open(result_file, 'rb') as f:
    results = pickle.load(f, encoding='latin1')

print("resultsの型:", type(results))
print("\nresultsの内容:")
print(results)

# 結果をDataFrameに変換
df = pd.DataFrame(results)
print("\nDataFrameのカラム:", df.columns)

# 自然性スコアでソート
df_sorted = df.sort_values(by='1score_min', ascending=False)

# 結果を表示
print("\n=== コードの自然性ランキング ===")
print("\n全件の結果:")
print(df_sorted[['file_path', 'line', '1score_min']])

# 基本統計情報の表示
print("\n=== 基本統計情報 ===")
print(df_sorted['1score_min'].describe())