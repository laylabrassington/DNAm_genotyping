#!/bin/bash
#SBATCH --mail-user=your_email@university.edu
#SBATCH --mail-type=ALL
#SBATCH -J reheader_vcfs
#SBATCH --mem=10GB
#SBATCH --time=01:00:00
#SBATCH --output=reheader_vcfs.out

ml StdEnv/2023 StdEnvACCRE/2023 gcc/12.3
ml bcftools/1.22

input_dir="/filepath/filter1outs"
output_dir="/filepath/filter1outs_reheaded"

mkdir -p "${output_dir}"

echo "${input_dir}"
echo "${output_dir}"

for file in "${input_dir}"/*.vcf.gz; do

    sample_name=$(basename "${file}" .vcf.gz)

    echo "reheader-ing ${sample_name}"

    echo "${sample_name}" > currsample.txt

    bcftools reheader \
        -s currsample.txt \
        -o "${output_dir}/${sample_name}.vcf.gz" \
        "${file}"

    bcftools index "${output_dir}/${sample_name}.vcf.gz"

done

rm currsample.txt

echo "Finished reheader-ing all VCFs"

