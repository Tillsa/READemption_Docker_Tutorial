#!/bin/bash

main(){
    readonly DOCKER_PATH=/usr/bin/docker
    readonly IMAGE_WITHOUT_TAG=reademption_105
    readonly IMAGE=reademption_105:latest
    readonly CONTAINER_NAME=reademption_container
    readonly READEMPTION_ANALYSIS_FOLDER=reademption_analysis
    readonly FTP_SOURCE=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/210/855/GCF_000210855.2_ASM21085v2
    readonly MAPPING_PROCESSES=6
    readonly COVERAGE_PROCESSES=6
    readonly GENE_QUANTI_PROCESSES=6



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
    ## running the analysis:
    build_reademption_image
    #build_reademption_image_no_cache
    create_running_container

    create_reademtption_folder
    download_reference_sequences
    download_annotation
    download_and_subsample_reads
    align_reads
    build_coverage_files
    run_gene_quanti
    run_deseq


    ## inspecting the container:
    #execute_command_ls
    #execute_command_tree
    #stop_container
    #start_container
    #remove_all_containers
    #execute_command_show_gene_quanti

}

## Running analysis

build_reademption_image(){
    $DOCKER_PATH build -f Dockerfile -t $IMAGE_WITHOUT_TAG .
}

# creates a running container with bash
create_running_container(){
    $DOCKER_PATH run --name $CONTAINER_NAME -it -d $IMAGE bash
}

# create the reademption input and outputfolders inside the container
create_reademtption_folder(){
    $DOCKER_PATH exec $CONTAINER_NAME \
      reademption create -f $READEMPTION_ANALYSIS_FOLDER
}

# download the reference sequences to the reademption iput folder inside the container
download_reference_sequences(){
  $DOCKER_PATH exec $CONTAINER_NAME \
    wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/reference_sequences/salmonella.fa.gz \
      ${FTP_SOURCE}/GCF_000210855.2_ASM21085v2_genomic.fna.gz
  $DOCKER_PATH exec $CONTAINER_NAME \
    gunzip ${READEMPTION_ANALYSIS_FOLDER}/input/reference_sequences/salmonella.fa.gz
}


download_annotation(){
    $DOCKER_PATH exec $CONTAINER_NAME \
      wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/annotations/salmonella.gff.gz \
        ${FTP_SOURCE}/GCF_000210855.2_ASM21085v2_genomic.gff.gz
    $DOCKER_PATH exec $CONTAINER_NAME \
      gunzip ${READEMPTION_ANALYSIS_FOLDER}/input/annotations/salmonella.gff.gz
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
			-a 95 \
			-l 20 \
			--poly_a_clipping \
			--progress \
			--split \
			     -f $READEMPTION_ANALYSIS_FOLDER

}

build_coverage_files(){
    $DOCKER_PATH exec $CONTAINER_NAME \
      reademption coverage \
      -p $COVERAGE_PROCESSES \
      -f $READEMPTION_ANALYSIS_FOLDER

    echo "coverage done"
}

run_gene_quanti(){
    $DOCKER_PATH exec $CONTAINER_NAME \
      reademption gene_quanti \
      -p $GENE_QUANTI_PROCESSES \
         -f $READEMPTION_ANALYSIS_FOLDER
    echo "gene quanti done"
}



run_deseq(){
    $DOCKER_PATH exec $CONTAINER_NAME \
			reademption deseq \
			--libs InSPI2_R1,InSPI2_R2,LSP_R1,LSP_R2 \
			--conditions replicate1,replicate2,replicate1,replicate2 \
         -f $READEMPTION_ANALYSIS_FOLDER
    echo "deseq done"
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

execute_command_show_gene_quanti(){
    #$DOCKER_PATH exec $CONTAINER_NAME pip show reademption

    $DOCKER_PATH exec $CONTAINER_NAME cat /usr/local/lib/python3.8/dist-packages/reademptionlib/gff3.py
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