#!/bin/bash
export XNAT_USER=${2}
export XNAT_PASS=${3}
export XNAT_HOST=${4}
sessionID=${1}
working_dir=/workinginput
output_directory=/workingoutput
final_output_directory=/outputinsidedocker
CALCULATION_DIR=/calculation
LATEX_DIR=/latex
IMAGES_DIR=/images
OUTPUTDIRNAME=/workingoutput #${2}
lung_atelectasis_calculation()
{

  #!/bin/bash

  #SESSION_ID=${1}
  #XNAT_USER=${2}
  #XNAT_PASS=${3}
  #TYPE_OF_PROGRAM=${4}
  #INPUTFILENAME=${1}

  #############################LUNG SEGMENTATION ##########################################
  for INPUTFILENAME in ${working_dir}/*.nii* ;
  do
  /opt/conda/envs/rapids/bin/python /software/lungsegmentation_module.py ${INPUTFILENAME} ${OUTPUTDIRNAME}
  done
  ################################### VESSEL SEGMENTATION ###############################################
  for INPUTFILENAME in ${working_dir}/*.nii* ;
  do
  /opt/conda/bin/python /software/vessel_segmentation_module.py ${INPUTFILENAME} ${OUTPUTDIRNAME}
  done

  for INPUTFILENAME in ${working_dir}/*.nii* ;
  do
  /opt/conda/bin/python  /software/atelectatis_perc_cal_module.py ${INPUTFILENAME} ${OUTPUTDIRNAME} ${IMAGES_DIR} ${CALCULATION_DIR} ${LATEX_DIR}
  done

}


copyoutput_to_snipr(){
sessionID=$1
scanID=$2
resource_dirname=$4 #"MASKS" #sys.argv[4]
file_suffix=$5
output_dir=$3
echo " I AM IN copyoutput_to_snipr "
python3 -c "
import sys
sys.path.append('/software');
from download_with_session_ID import *;
uploadfile()" ${sessionID} ${scanID} ${output_dir} ${resource_dirname} ${file_suffix}  # ${infarctfile_present}  ##$static_template_image $new_image $backslicenumber #$single_slice_filename

}


copy_masks_data() {
echo " I AM IN copy_masks_data "
# rm -r /ZIPFILEDIR/*
sessionID=${1}
scanID=${2}
resource_dirname=${3} #str(sys.argv[4])
output_dirname=${4}  #str(sys.argv[3])
echo output_dirname::${output_dirname}
python3 -c "
import sys
sys.path.append('/software');
from download_with_session_ID import *;
downloadfiletolocaldir()" ${sessionID}  ${scanID}  ${resource_dirname}  ${output_dirname}    ### ${infarctfile_present}  ##$static_template_image $new_image $backslicenumber #$single_slice_filename


}

copy_scan_data() {
		echo " I AM IN copy_scan_data "
# rm -r /ZIPFILEDIR/*
# rm -r ${working_dir}/*
# rm -r ${output_dir}/*
sessionID=$1
dir_to_receive_the_data=${2}
resource_dir=${3}
    # sessionId=sys.argv[1]
    # dir_to_receive_the_data=sys.argv[2]
    # resource_dir=sys.argv[3]
# scanID=$2
python -c "
import sys
sys.path.append('/Stroke_CT_Processing');
from download_with_session_ID import *;
get_relevantfile_in_A_DIRECTORY()" ${sessionID}  ${dir_to_receive_the_data} ${resource_dir}

}


run_IML_NWU_CSF_CALC()

{
this_filename=${1}
this_betfilename=${2}
this_csfmaskfilename=${3}
this_infarctmaskfilename=${4}
echo "BET USING LEVELSET MASK"

/software/bet_withlevelset.sh $this_filename ${this_betfilename} #${output_directory} #Helsinki2000_1019_10132014_1048_Head_2.0_ax_Tilt_1_levelset # ${3} # Helsinki2000_702_12172013_2318_Head_2.0_ax_levelset.nii.gz #${3} # $6 $7 $8 $9 ${10}

echo "bet_withlevelset successful" > ${output_directory}/success.txt
this_filename_brain=${this_filename%.nii*}_brain_f.nii.gz
# cp ${this_filename_brain} ${output_directory}/ #  ${final_output_directory}/
echo "LINEAR REGISTRATION TO TEMPLATE"
/software/linear_rigid_registration.sh ${this_filename_brain} #${templatefilename} #$3 ${6} WUSTL_233_11122015_0840__levelset_brain_f.nii.gz
echo "linear_rigid_registration successful" >> ${output_directory}/success.txt
echo "RUNNING IML FSL PART"
/software/ideal_midline_fslpart.sh ${this_filename} # ${templatefilename} ${mask_on_template}  #$9 #${10} #$8
echo "ideal_midline_fslpart successful" >> ${output_directory}/success.txt
echo "RUNNING IML PYTHON PART"

/software/ideal_midline_pythonpart.sh  ${this_filename} #${templatefilename}  #$3 #$8 $9 ${10}
echo "ideal_midline_pythonpart successful" >> ${output_directory}/success.txt

echo "RUNNING NWU AND CSF VOLUME CALCULATION "

/software/nwu_csf_volume.sh  ${this_filename}   ${this_betfilename} ${this_csfmaskfilename} ${this_infarctmaskfilename}  ${lower_threshold} ${upper_threshold}
echo "nwu_csf_volume successful" >> ${output_directory}/success.txt
thisfile_basename=$(basename $this_filename)
# for texfile in $(/usr/lib/fsl/5.0/remove_ext ${output_directory}/$thisfile_basename)*.tex ;
for texfile in  ${output_directory}/*.tex ;
do
pdflatex -halt-on-error -interaction=nonstopmode   -output-directory=${output_directory} $texfile  ##${output_directory}/$(/usr/lib/fsl/5.0/remove_ext $this_filename)*.tex
rm ${output_directory}/*.aux
rm ${output_directory}/*.log
done

for filetocopy in $(/usr/lib/fsl/5.0/remove_ext ${output_directory}/$thisfile_basename)*_brain_f.nii.gz ;
do
cp ${filetocopy} ${final_output_directory}/
done

for filetocopy in $(/usr/lib/fsl/5.0/remove_ext ${output_directory}/$thisfile_basename)*.mat ;
do
cp ${filetocopy} ${final_output_directory}/
done

for filetocopy in ${output_directory}/*.pdf ;
do
cp ${filetocopy} ${final_output_directory}/
done
for filetocopy in  ${output_directory}/*.csv ;
do
cp ${filetocopy} ${final_output_directory}/
done

}

nwucalculation_each_scan(){


eachfile_basename_noext=''
originalfile_basename=''
original_ct_file=''
for eachfile in ${working_dir}/*.nii ;
do
original_ct_file=${eachfile}
eachfile_basename=$(basename ${eachfile})
originalfile_basename=${eachfile_basename}
eachfile_basename_noext=${eachfile_basename%.nii*}


############## files basename ##################################
grayfilename=${eachfile_basename_noext}_resaved_levelset.nii
betfilename=${eachfile_basename_noext}_resaved_levelset_bet.nii.gz
csffilename=${eachfile_basename_noext}_resaved_csf_unet.nii.gz
infarctfilename=${eachfile_basename_noext}_resaved_infarct_auto_removesmall.nii.gz
################################################
############## copy those files to the docker image ##################################
cp ${working_dir}/${betfilename}  ${output_directory}/
cp ${working_dir}/${csffilename}  ${output_directory}/
cp ${working_dir}/${infarctfilename}  ${output_directory}/
####################################################################################
source /software/bash_functions_forhost.sh

cp ${original_ct_file}  ${output_directory}/${grayfilename}
grayimage=${output_directory}/${grayfilename} #${gray_output_subdir}/${eachfile_basename_noext}_resaved_levelset.nii
###########################################################################

#### originalfiel: .nii
#### betfile: *bet.nii.gz


# original_ct_file=$original_CT_directory_names/
levelset_infarct_mask_file=${output_directory}/${infarctfilename}
echo "levelset_infarct_mask_file:${levelset_infarct_mask_file}"
## preprocessing infarct mask:
python3 -c "
import sys ;
sys.path.append('/software/') ;
from utilities_simple_trimmed import * ;  levelset2originalRF_new_flip()" "${original_ct_file}"  "${levelset_infarct_mask_file}"  "${output_directory}"


## preprocessing bet mask:
levelset_bet_mask_file=${output_directory}/${betfilename}
echo "levelset_bet_mask_file:${levelset_bet_mask_file}"
python3 -c "

import sys ;
sys.path.append('/software/') ;
from utilities_simple_trimmed import * ;  levelset2originalRF_new_flip()" "${original_ct_file}"  "${levelset_bet_mask_file}"  "${output_directory}"

#### preprocessing csf mask:
levelset_csf_mask_file=${output_directory}/${csffilename}
echo "levelset_csf_mask_file:${levelset_csf_mask_file}"
python3 -c "
import sys ;
sys.path.append('/software/') ;
from utilities_simple_trimmed import * ;   levelset2originalRF_new_flip()" "${original_ct_file}"  "${levelset_csf_mask_file}"  "${output_directory}"


lower_threshold=0
upper_threshold=20
templatefilename=scct_strippedResampled1.nii.gz
mask_on_template=midlinecssfResampled1.nii.gz




x=$grayimage
bet_mask_filename=${output_directory}/${betfilename}
infarct_mask_filename=${output_directory}/${infarctfilename}
csf_mask_filename=${output_directory}/${csffilename}
run_IML_NWU_CSF_CALC  $x ${bet_mask_filename} ${csf_mask_filename} ${infarct_mask_filename}


done


# for f in ${output_directory}/*; do
#     # if [ -d "$f" ]; then
#         # $f is a directory
#         rm -r $f
#     # fi
# done

}



# #####################################################
get_nifti_scan_uri(){
# csvfilename=sys.argv[1]
# dir_to_save=sys.argv[2]
# echo " I AM IN copy_scan_data "
# rm -r /ZIPFILEDIR/*

sessionID=$1
working_dir=${2}
output_csvfile=${3}
rm -r ${working_dir}/*
output_dir=$(dirname ${output_csvfile})
rm -r ${output_dir}/*
# scanID=$2
python3 -c "
import sys
sys.path.append('/software');
from download_with_session_ID import *;
call_decision_which_nifti()" ${sessionID}  ${working_dir} ${output_csvfile}

}




copy_scan_data() {
csvfilename=${1} #sys.argv[1]
dir_to_save=${2} #sys.argv[2]
# 		echo " I AM IN copy_scan_data "
# rm -r /ZIPFILEDIR/*
# rm -r ${working_dir}/*
# rm -r ${output_dir}/*
# sessionID=$1
# # scanID=$2
python3 -c "
import sys
sys.path.append('/software');
from download_with_session_ID import *;
downloadniftiwithuri_withcsv()" ${csvfilename}  ${dir_to_save}


}


function  download_files_in_a_resource() {
local sessionId=${1} #sys.argv[1]
local scanID=${2}
local resource_dirname=${3} #sys.argv[2]
local dir_to_save=${4} ##sys.argv[2]
python3 -c "
import sys
sys.path.append('/software');
from download_with_session_ID import *;
download_files_in_scans_resources_withname_sh()" ${sessionId} ${scanID} ${resource_dirname}  ${dir_to_save}


}


getmaskfilesscanmetadata()
{
# def get_maskfile_scan_metadata():
sessionId=${1} #sys.argv[1]
scanId=${2} # sys.argv[2]
resource_foldername=${3} # sys.argv[3]
dir_to_save=${4} # sys.argv[4]
csvfilename=${5} # sys.argv[5]
python3 -c "
import sys
sys.path.append('/software');
from download_with_session_ID import *;
get_maskfile_scan_metadata()" ${sessionId}  ${scanId}  ${resource_foldername} ${dir_to_save} ${csvfilename}
}

########################################################################
# GET THE SINGLE CT NIFTI FILE NAME AND COPY IT TO THE WORKING_DIR
niftifile_csvfilename=${working_dir}/'this_session_final_ct.csv'
get_nifti_scan_uri ${sessionID}  ${working_dir} ${niftifile_csvfilename}
copy_scan_data ${niftifile_csvfilename} ${working_dir}
#lung_atelectasis_calculation
#
#
#
################################################################################################################
#
### GET THE RESPECTIVS MASKS NIFTI FILE NAME AND COPY IT TO THE WORKING_DIR
#
#######################################################################################
##resource_dirname='MASKS'
##output_dirname=${working_dir}
#while IFS=',' read -ra array; do
#scanID=${array[2]}
#echo sessionId::${sessionID}
#echo scanId::${scanID}
#echo "ARRAY${array[0]}::${array[1]}::${array[2]}::${array[3]}"
#done < <( tail -n +2 "${niftifile_csvfilename}" )
##echo working_dir::${working_dir}
##echo output_dirname::${output_dirname}
##copy_masks_data   ${sessionID}  ${scanID} ${resource_dirname} ${output_dirname}
########################################################################################################################
### CALCULATE EDEMA BIOMARKERS
##nwucalculation_each_scan
#######################################################################################################################
### COPY IT TO THE SNIPR RESPECTIVE SCAN RESOURCES
#snipr_output_foldername="LUNG_ATELECTASIS"
#file_suffixes=(  .pdf .csv ) #sys.argv[5]
#for file_suffix in ${file_suffixes[@]}
#do
#    copyoutput_to_snipr  ${sessionID} ${scanID} "${CALCULATION_DIR}"  ${snipr_output_foldername}  ${file_suffix}
#done
#######################################################################################################################
#
#for file_suffix in ${file_suffixes[@]}
#do
#    copyoutput_to_snipr  ${sessionID} ${scanID} "${LATEX_DIR}"  ${snipr_output_foldername}  ${file_suffix}
#done
######################################################################################################################
#scanID=1
#snipr_output_foldername="PROCESSING_FILES"
#file_suffixes=( .gz )
#for file_suffix in ${file_suffixes[@]}
#do
#    copyoutput_to_snipr  ${sessionID} ${scanID} "${OUTPUTDIRNAME}"  ${snipr_output_foldername}  ${file_suffix}
#done

final_output_directory=/outputinsidedocker
while IFS=',' read -ra array; do
scanID=1 #${array[2]}
echo sessionId::${sessionID}
#echo scanId::${scanID}
#echo "ARRAY${array[0]}::${array[1]}::${array[2]}::${array[3]}"
resource_dirname="PROCESSING_FILES"
dir_to_save=${OUTPUTDIRNAME}
#${sessionID}  ${working_dir}
download_files_in_a_resource ${sessionID} ${scanID} ${resource_dirname}  ${dir_to_save}
resource_dirname="NIFTI"
download_files_in_a_resource ${sessionID} ${scanID} ${resource_dirname}  ${dir_to_save}

gray_image_filename=${working_dir}/${array[1]}
lung_mask=${OUTPUTDIRNAME}/${array[1]%.nii*}_lung_gray_seg_LTRCLobes_R231_bw.nii.gz
curvature_mask=${OUTPUTDIRNAME}/${array[1]%.nii*}_2_5_15_vessels_modfd.nii.gz
atelectasis_mask=${OUTPUTDIRNAME}/${array[1]%.nii*}_lung_mask_seg_gt_neg500LTRCLobes_R231.nii.gz
savetodir=${final_output_directory}
echo '${gray_image_filename} ${lung_mask} ${curvature_mask} ${atelectasis_mask} ${savetodir}'::"${gray_image_filename} ${lung_mask} ${curvature_mask} ${atelectasis_mask} ${savetodir}"
#savetodir,gray_image_filename,lung_mask,,

call_create_imagesfor_presentation_arguments=('call_create_imagesfor_presentation' ${gray_image_filename} ${lung_mask} ${curvature_mask} ${atelectasis_mask} ${savetodir})
outputfiles_present=$(python utilities_simple_forlungproject.py "${call_create_imagesfor_presentation_arguments[@]}")
echo "outputfiles_present:: "${outputfiles_present: -1}"::outputfiles_present"
/software/flowchart_lungatelectasis_project.sh ${array[1]%.nii*}  227 ${savetodir}
done < <( tail -n +2 "${niftifile_csvfilename}" )

pdflatex template_for_flowchart.tex
cp  *.tex ${savetodir}/ #template_for_flowchart.tex
#cp  template_for_flowchart.pdf ${OUTPUTDIRNAME}/template_for_flowchart.pdf

#slice_number=
#CALCULATION_DIR=/calculation
#LATEX_DIR=/latex
#IMAGES_DIR=/images