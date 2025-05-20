module load singularity
singularity shell codebert-nt.sif
python ~/CodeBERT_naruralness/CodeBERT-nt/naturalness_analysis_refactoring/scripts/task_generator/generate_task_list.py
