#!/bin/bash
#SBATCH --mail-user=your_email@university.edu
#SBATCH --mail-type=ALL
#SBATCH -J merge_filter2
#SBATCH --time=04:00:00
#SBATCH --mem=16GB
#SBATCH --output=merge_filter2.out

ml StdEnv/2023 StdEnvACCRE/2023 gcc/12.3
ml samtools/1.22.1
ml tabix/0.2.6
ml bcftools/1.22
ml plink/2.00-20251019-avx2

input_dir="/filepath/outputs/filter1outs_reheaded"
merged_dir="/filepath/outputs/merged"
filter_dir="/filepath/outputs/filter2outs"

mkdir -p "${merged_dir}"
mkdir -p "${filter_dir}"

echo "${merged_dir}"
echo "${filter_dir}"


# --------------------------------------------------
# 1. Merge all individual VCFs
# --------------------------------------------------

echo "Starting VCF merge"

bcftools merge \
    "${input_dir}"/*.vcf.gz \
    -Oz \
    -o "${merged_dir}/all_samples.vcf.gz"

echo "Finished VCF merge"


# Index merged VCF

bcftools index "${merged_dir}/all_samples.vcf.gz"

echo "Finished indexing merged VCF"


# Check number of samples

echo "Number of samples in merged VCF:"
bcftools query -l "${merged_dir}/all_samples.vcf.gz" | wc -l


# --------------------------------------------------
# 2. Variant filtering
# --------------------------------------------------
# Keep biallelic variants
# Remove sites with >25% missingness
# Calculate allele frequency
# Remove variants with AF <= 0.05

echo "Starting variant filtering"

bcftools view \
    "${merged_dir}/all_samples.vcf.gz" \
    -m2 -M2 \
    -i 'F_MISSING<0.25' | \
bcftools +fill-tags \
    -- -t AF | \
bcftools filter \
    -e 'INFO/AF <= 0.05' \
    -Oz \
    -o "${filter_dir}/all_samples_after2.vcf.gz"

echo "Finished variant filtering"


# Index filtered VCF

bcftools index "${filter_dir}/all_samples_after2.vcf.gz"


# --------------------------------------------------
# 3. Sample missingness filtering
# --------------------------------------------------
# Remove samples with >75% missing genotypes

echo "Starting sample missingness filtering"

plink2 \
    --vcf "${filter_dir}/all_samples_after2.vcf.gz" \
    --mind 0.75 \
    --recode vcf bgz \
    --out "${filter_dir}/all_samples_after2a"

echo "Finished sample missingness filtering"


# --------------------------------------------------
# 4. HWE filtering
# --------------------------------------------------

echo "Starting HWE filtering"

plink2 \
    --vcf "${filter_dir}/all_samples_after2a.vcf.gz" \
    --hwe 1e-8 \
    --set-all-var-ids '@:#[$r,$a]' \
    --make-bed \
    --out "${filter_dir}/all_samples_HWEfiltered"

echo "Finished HWE filtering"


# --------------------------------------------------
# 5. LD pruning
# --------------------------------------------------

echo "Starting LD pruning"

plink2 \
    --bfile "${filter_dir}/all_samples_HWEfiltered" \
    --indep-pairwise 50 5 0.2 \
    --out "${filter_dir}/LDfiltered"

echo "Finished LD pruning"


# --------------------------------------------------
# 6. Extract LD-pruned sites
# --------------------------------------------------

echo "Starting extraction of LD-pruned sites"

plink2 \
    --bfile "${filter_dir}/all_samples_HWEfiltered" \
    --extract "${filter_dir}/LDfiltered.prune.in" \
    --make-bed \
    --out "${filter_dir}/all_samples_after3"

echo "Finished extraction of LD-pruned sites"


echo "===================================="
echo "FILTER 2 COMPLETE"
echo "===================================="








