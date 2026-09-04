# DNAm_genotyping
code and instructions for calling genotype info and making a kinship matrix from DNAm data
starting with .bam files 

## Step 1:
- bam2vcf.sh : converts .bam files to vcf files for each sample/individual 
- other necessary inputs: cgmaptools (module) and reference genome (hg38.fa)

## Step 2:
- filter1.sh : filters indiviudal vcf files
- other necessary inputs: 1000 Genomes SNPs (gnomAD_filtered)

### Step 2.5: 
- rehead.sh : *if needed, adjusts sample names in individual .vcf files to match the filenames
- can check if this is necessary using: `for f in *.vcf.gz; do echo -n "$(basename "$f"): "; bcftools query -l "$f"; done` 

## Step 3: 
- merge_filter2.sh : merge into 1 vcf and filter

## Step 4:
- make relatedness matrix and/or PCA using KING and/or plink
- links
    - king (https://www.kingrelatedness.com/manual.shtml)
    - plink (https://www.cog-genomics.org/plink/) (https://zzz.bwh.harvard.edu/plink/tutorial.shtml)

