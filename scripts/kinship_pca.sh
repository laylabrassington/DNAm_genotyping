#there's "kinship" and "relatedness" from the king program
  #kinship will give negative estimates of relatedness
  #relatedness caps its lower bound at 0.0884 and just assigns anything below that at 0

#make sure you have clear naming set up when you run these functions. otherwise it will default pick the file prefix based on the input file and overwrite any file that has that name already.

#this code is written as if you're in the directory with the files you're running this on 

king -b all_samples_after3.bed --related --degree 2 --prefix king_related

king -b all_samples_after3.bed --kinship --prefix king_kinship

plink --bfile all_samples_after3 --pca --out plink_pca
