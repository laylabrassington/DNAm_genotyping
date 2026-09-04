#!/bin/bash
#SBATCH --mail-user=your_email@university.edu
#SBATCH --mail-type=ALL
#SBATCH -J bam2vcf
#SBATCH -n 1
#SBATCH --cpus-per-task=4
#SBATCH --time=30:00:00
#SBATCH --mem=30GB
#SBATCH --output=bam2vcf.%a.out
#SBATCH --array=X-XX%X #dependent on your number of samples

echo "loading modules"
ml StdEnv/2023 StdEnvACCRE/2023 gcc/12.3
ml samtools/1.22.1
ml tabix/0.2.6
ml bcftools/1.22

# cgmaptools is installed outside the ACCRE module system
export PATH=/filepath/cgmaptools:$PATH

##############################
# SET UP
##############################

echo "define directories"

# Main directory where files are located
base_dir=filepath

# Sample ID list
id_list=/filepath/list_of_file_ids.txt

# Reference genome
in_genome=/filepath/hg38.fa

# Input BAM directory
bam_dir=/filepath

# Output directories
sorted_dir=$base_dir/outputs/sorted
converted_dir=$base_dir/outputs/converted
vcf_dir=$base_dir/outputs/vcfs
out_dir=$base_dir/outputs/outs
final_vcf_dir=$base_dir/outputs/finalvcfs

# Get sample ID from the sample list
sampleID=$(sed -n ${SLURM_ARRAY_TASK_ID}p $id_list)

# Print sample ID
echo "sample ID: $sampleID"

##############################
# INPUT FILES
##############################

in_bam=$bam_dir/${sampleID}/${sampleID}.bam

##############################
# OUTPUT FILES
##############################

# Sorted BAM
out_bam_sorted=$sorted_dir/${sampleID}_sorted.bam

# Sorted BAM index
out_bam_sorted_index=$sorted_dir/${sampleID}_sorted.bam.bai

# Chromosome-specific BAM directory
out_bam_chr=$sorted_dir/${sampleID}

# Converted CGmap directory
out_converted=$converted_dir/${sampleID}

# Chromosome-specific VCF directory
out_vcf=$vcf_dir/${sampleID}

# cgmaptools output directory
out_txt=$out_dir/${sampleID}

# Final merged VCF
out_final_vcf=$final_vcf_dir/${sampleID}.vcf.gz


##############################
# MAKE DIRECTORIES
##############################

mkdir -p $out_bam_chr
mkdir -p $out_converted
mkdir -p $out_vcf
mkdir -p $out_txt
mkdir -p $final_vcf_dir


##############################
# PRINT FILE INFORMATION
##############################

echo "sample ID: $sampleID"
echo "input BAM: $in_bam"
echo "reference genome: $in_genome"
echo "final VCF: $out_final_vcf"


##############################
# STEP 1: SORT AND SPLIT BAM
##############################

echo "sorting BAM..."
samtools sort -o $out_bam_sorted $in_bam
samtools view $in_bam | wc -l
echo "sort for ${sampleID} done"

echo "indexing sorted BAM..."
samtools index $out_bam_sorted

echo "splitting BAM by chromosome..."

for chr in {1..22} X Y; do
    if samtools idxstats "$out_bam_sorted" | awk '{print $1}' | grep -q -w "chr$chr"; then
       echo "Starting chr ${chr} split"
       samtools view -b $out_bam_sorted "chr${chr}" > $out_bam_chr/chr${chr}.bam
  fi
 done

echo "split done"


##############################
# STEP 2: BAM TO CGMAP
##############################

echo "converting BAM files to CGmap..."

for chr in {1..22} X Y; do
    if [ -f "$out_bam_chr/chr${chr}.bam" ]; then

        echo "$(date): Starting chr ${chr}"

        cgmaptools convert bam2cgmap \
            -b $out_bam_chr/chr${chr}.bam \
            --rmOverlap \
            -g $in_genome \
            -o $out_converted/chr${chr}

        echo "$(date): Finished chr ${chr}"

    fi
done

echo "$(date): BAM to CGmap conversion done"



##############################
# STEP 3: SNV CALLING AND VCF FILTERING
##############################

echo "calling SNVs and filtering VCFs..."

merge_files=""

for chr in {1..22} X Y; do
    if [ -f "$out_bam_chr/chr${chr}.bam" ]; then
        echo "$(date): Starting chr ${chr}"
        
        # SNV calling
        cgmaptools snv -i $out_converted/chr${chr}.ATCGmap.gz -m bayes -v $out_vcf/chr${chr}.vcf --bayes-dynamicP -o $out_txt/chr${chr}.out --bayes-e=0.01 -a
        
        # Filter and remove DP<5
        bgzip -c $out_vcf/chr${chr}.vcf > $out_vcf/chr${chr}.vcf.gz
        tabix -f -p vcf $out_vcf/chr${chr}.vcf.gz
        bcftools view -f 'PASS,.' $out_vcf/chr${chr}.vcf.gz --output-type z > $out_vcf/chr${chr}_pass.vcf.gz
        tabix -f -p vcf $out_vcf/chr${chr}_pass.vcf.gz
        bcftools filter -i 'FORMAT/DP>4' $out_vcf/chr${chr}_pass.vcf.gz --output-type z > $out_vcf/chr${chr}_pass_DP5.vcf.gz
        tabix -f -p vcf $out_vcf/chr${chr}_pass_DP5.vcf.gz
        merge_files="$merge_files $out_vcf/chr${chr}_pass_DP5.vcf.gz"
        
        echo "$(date): Finished chr ${chr}"
    fi
done

echo "$(date): SNV calling and filtering completed successfully"

##############################
# STEP 4: MERGE FINAL VCF
##############################

echo "$(date): merging chromosome VCFs..."

bcftools concat $merge_files -Oz -o $out_final_vcf

echo "$(date): final VCF created:"
echo $out_final_vcf

##############################
# CLEANUP
##############################

echo "cleaning up intermediate files..."

rm -f "$out_bam_sorted"
rm -rf "$out_txt"
rm -rf "$out_converted"
rm -rf "$out_vcf"
rm -rf "$out_bam_chr"
rm -rf "$out_vcf/chr${chr}_pass.vcf.gz"
rm -rf "$out_vcf/chr${chr}.vcf"

##############################
# DONE
##############################

echo "done with ${sampleID}"