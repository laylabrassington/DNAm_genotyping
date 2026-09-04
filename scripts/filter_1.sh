#!/bin/bash
#SBATCH --mail-user=your_email@university.edu
#SBATCH --mail-type=ALL
#SBATCH -J filter1
#SBATCH --time=06:00:00
#SBATCH --mem=16GB
#SBATCH --output=filter1.%a.out
#SBATCH --array=X-XX%X #dependent on your number of samples

ml StdEnv/2023 gcc/12.3 bcftools/1.22

##############################
# SET UP
##############################

sample=$(sed -n "${SLURM_ARRAY_TASK_ID}p" /filepath/list_of_sample_ids)
echo "sample = ${sample}"

path=/filepath

input="${path}/outputs/finalvcfs/${sample}.vcf.gz"
output="${path}/outputs/filter1outs/${sample}.vcf.gz"

echo "Input: ${input}"
echo "Output: ${output}"

mkdir -p "${path}/outputs/filter1outs"

ls -lh "${input}"

##############################
# STEP 1 
##############################


echo "starting bcftools filters..."

bcftools view -m1 -M2 "${input}" |
    bcftools view -e 'ALT~"Y" || ALT~"R"' |
    bcftools filter -i 'FORMAT/DP>9' |
    bcftools view -e '(REF="C" && ALT="T") || (REF="T" && ALT="C")' |
    bcftools view -e '(REF="A" && ALT="G") || (REF="G" && ALT="A")' \
    -o "${output}" -Oz

echo "filtering finished"

ls -lh "${output}"

echo "indexing..."

bcftools index "${output}"

echo "done with bcftools step"


##############################
# STEP 2: run 1000 genome filter on vcfs
##############################

outputs=/filepath
path_1KG=/filepath/gnomAD_filtered

mkdir -p "${outputs}/chrs/${sample}"

for chr in {1..22}; do
    echo "Starting chr ${chr}"
    
    # Split by chromosome
    bcftools view \
        "${outputs}/filter1outs/${sample}.vcf.gz" \
        --regions "chr${chr}" \
        -Oz \
        -o "${outputs}/chrs/${sample}/chr${chr}.vcf.gz"
    
    # Index
    bcftools index "${outputs}/chrs/${sample}/chr${chr}.vcf.gz"

    echo "chr ${chr} split and indexed"

    # Keep variants that overlap the 1000 Genomes positions
    bcftools view \
        -R "${path_1KG}/gnomad.genomes.v3.1.2.hgdp_tgp.chr${chr}.filter.vcf.gz" \
        "${outputs}/chrs/${sample}/chr${chr}.vcf.gz" \
        -Oz \
        -o "${outputs}/chrs/${sample}/chr${chr}_filtered.vcf.gz"

    # Index filtered VCF
    bcftools index "${outputs}/chrs/${sample}/chr${chr}_filtered.vcf.gz"

    echo "finished chr ${chr}"

done

##############################
# STEP 3: concatonate the chr files to 1 file 
##############################

echo "starting concat"

find "${outputs}/chrs/${sample}" -name 'chr*_filtered.vcf.gz' | sort -V \
    > "${outputs}/chrs/${sample}/concatme.txt"

bcftools concat \
    -f "${outputs}/chrs/${sample}/concatme.txt" \
    -Oz \
    -o "${outputs}/filter1outs/${sample}.vcf.gz"

bcftools index "${outputs}/filter1outs/${sample}.vcf.gz"

rm -r "${outputs}/chrs/${sample}"

echo "finished with ${sample}"

