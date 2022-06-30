#!/bin/bash

main(){
    readonly DOCKER_PATH=/usr/bin/docker
    readonly IMAGE_WITHOUT_TAG=reademption
    readonly IMAGE=tillsauerwein/reademption:2.0.0
    readonly CONTAINER_NAME=reademption_container
    readonly READEMPTION_ANALYSIS_FOLDER=reademption_analysis
    readonly FTP_SOURCE=ftp://ftp.ncbi.nih.gov/genomes/archive/old_refseq/Bacteria/Salmonella_enterica_serovar_Typhimurium_SL1344_uid86645/
    readonly MAPPING_PROCESSES=6
    readonly COVERAGE_PROCESSES=6
    readonly GENE_QUANTI_PROCESSES=6
    readonly LOCAL_OUTOUT_PATH="."



    if [ ${#@} -eq 0 ]
    then
        echo "Specify function to call or 'all' for running all functions"
        echo "Avaible functions are: "
        grep "(){" run.sh | grep -v "^all()" |  grep -v "^main(){" |  grep -v "^#"  | grep -v 'grep "(){"' | sed "s/(){//"
    else
        "$@"
    fi
}

all(){
    ## Creating image and container:
    #build_reademption_image
    create_running_container
    ## Running the analysis:
    create_reademption_folder
    download_reference_sequences
    modify_fasta_headers
    download_annotation
    download_and_subsample_reads
    align_reads
    build_coverage_files
    run_gene_quanti
    run_deseq
    run_viz_align
    run_viz_gene_quanti
    run_viz_deseq
    copy_analysis_to_local


    ## inspecting the container:
    #build_reademption_image_no_cache
    #execute_command_ls
    #execute_command_tree
    #show_containers
    #stop_container
    #start_container
    #remove_all_containers

}

## Running analysis

build_reademption_image(){
    $DOCKER_PATH build -f Dockerfile -t $IMAGE .
}

# creates a running container with bash
create_running_container(){
    $DOCKER_PATH run --name $CONTAINER_NAME -it -d $IMAGE bash
}

# create the reademption input and outputfolders inside the container
create_reademption_folder(){
    $DOCKER_PATH exec $CONTAINER_NAME \
      reademption create --project_path $READEMPTION_ANALYSIS_FOLDER --species salmonella="Salmonella Typhimurium"
}

# download the reference sequences to the reademption iput folder inside the container
download_reference_sequences(){
  $DOCKER_PATH exec $CONTAINER_NAME \
  wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_016810.fa $FTP_SOURCE/NC_016810.fna
  $DOCKER_PATH exec $CONTAINER_NAME \
  wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_017718.fa $FTP_SOURCE/NC_017718.fna
  $DOCKER_PATH exec $CONTAINER_NAME \
  wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_017719.fa $FTP_SOURCE/NC_017719.fna
  $DOCKER_PATH exec $CONTAINER_NAME \
  wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_017720.fa $FTP_SOURCE/NC_017720.fna
}
# Modify fasta headers of ref seq

modify_fasta_headers(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    sed -i "s/>/>NC_016810.1 /" ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_016810.fa
    $DOCKER_PATH exec $CONTAINER_NAME \
    sed -i "s/>/>NC_017718.1 /" ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_017718.fa
    $DOCKER_PATH exec $CONTAINER_NAME \
    sed -i "s/>/>NC_017719.1 /" ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_017719.fa
    $DOCKER_PATH exec $CONTAINER_NAME \
    sed -i "s/>/>NC_017720.1 /" ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_reference_sequences/NC_017720.fa
}



download_annotation(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    wget -P ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_annotations https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/210/855/GCF_000210855.2_ASM21085v2/GCF_000210855.2_ASM21085v2_genomic.gff.gz
    $DOCKER_PATH exec $CONTAINER_NAME \
    gunzip ${READEMPTION_ANALYSIS_FOLDER}/input/salmonella_annotations/GCF_000210855.2_ASM21085v2_genomic.gff.gz


}

download_and_subsample_reads(){
    $DOCKER_PATH exec $CONTAINER_NAME \
      wget -P ${READEMPTION_ANALYSIS_FOLDER}/input/reads http://reademptiondata.imib-zinf.net/InSPI2_R1.fa.bz2
    $DOCKER_PATH exec $CONTAINER_NAME \
      wget -P ${READEMPTION_ANALYSIS_FOLDER}/input/reads http://reademptiondata.imib-zinf.net/InSPI2_R2.fa.bz2
    $DOCKER_PATH exec $CONTAINER_NAME \
      wget -P ${READEMPTION_ANALYSIS_FOLDER}/input/reads http://reademptiondata.imib-zinf.net/LSP_R1.fa.bz2
    $DOCKER_PATH exec $CONTAINER_NAME \
      wget -P ${READEMPTION_ANALYSIS_FOLDER}/input/reads http://reademptiondata.imib-zinf.net/LSP_R2.fa.bz2
}

align_reads(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    reademption align \
    -p ${MAPPING_PROCESSES} \
    --poly_a_clipping \
    --project_path $READEMPTION_ANALYSIS_FOLDER

}

build_coverage_files(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    reademption coverage \
    -p ${COVERAGE_PROCESSES} \
    --project_path $READEMPTION_ANALYSIS_FOLDER
}

run_gene_quanti(){
    $DOCKER_PATH exec $CONTAINER_NAME \
      reademption gene_quanti \
      -p ${GENE_QUANTI_PROCESSES} \
      --features CDS,tRNA,rRNA \
      --project_path $READEMPTION_ANALYSIS_FOLDER
}



run_deseq(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    reademption deseq \
    -l InSPI2_R1.fa.bz2,InSPI2_R2.fa.bz2,LSP_R1.fa.bz2,LSP_R2.fa.bz2 \
    -c InSPI2,InSPI2,LSP,LSP \
    -r 1,2,1,2 \
    --libs_by_species salmonella=InSPI2_R1,InSPI2_R2,LSP_R1,LSP_R2 \
    --project_path $READEMPTION_ANALYSIS_FOLDER
}

run_viz_align(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    reademption viz_align \
    --project_path $READEMPTION_ANALYSIS_FOLDER
}
run_viz_gene_quanti(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    reademption viz_gene_quanti \
    --project_path $READEMPTION_ANALYSIS_FOLDER
}
run_viz_deseq(){
    $DOCKER_PATH exec $CONTAINER_NAME \
    reademption viz_deseq \
    --project_path $READEMPTION_ANALYSIS_FOLDER
}

copy_analysis_to_local(){
  $DOCKER_PATH cp ${CONTAINER_NAME}:/root/${READEMPTION_ANALYSIS_FOLDER} ${LOCAL_OUTOUT_PATH}
}

## Inspecting

# execute a command and keep the container running
# only works when container is running
build_reademption_image_no_cache(){
    $DOCKER_PATH build --no-cache -f Dockerfile -t $IMAGE_WITHOUT_TAG .
}


execute_command_ls(){
    $DOCKER_PATH exec $CONTAINER_NAME ls
}

show_reademption_version(){
    $DOCKER_PATH exec $CONTAINER_NAME reademption --version
}

# execute a command and keep the container running
# only works when container is running
execute_command_tree(){
    $DOCKER_PATH exec $CONTAINER_NAME tree $READEMPTION_ANALYSIS_FOLDER
}


show_containers(){
   $DOCKER_PATH ps -a
}

# stop the container
stop_container(){
    $DOCKER_PATH stop $CONTAINER_NAME
}

# start container and keep it runnning
start_container(){
    $DOCKER_PATH start $CONTAINER_NAME
}


remove_all_containers(){
  $DOCKER_PATH container prune
}

main $@