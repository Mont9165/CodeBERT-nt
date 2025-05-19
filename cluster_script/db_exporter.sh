#!/bin/bash

#SBATCH --job-name=db_exporter
#SBATCH --output=logs/main_%A_%a.out
#SBATCH --error=errors/main_%A_%a.err
#SBATCH --time=10:00:00
#SBATCH --partition=hmem_long
#SBATCH --ntasks=1
#SBATCH --mem=512G
#SBATCH --cpus-per-task=4

mkdir -p errors
mkdir -p logs
module load singularity
singularity shell codebert-nt.sif
python ~/CodeBERT_naruralness/CodeBERT-nt/naturalness_analysis_refactoring/scripts/db_exporter/db_to_csv_exporter.py
