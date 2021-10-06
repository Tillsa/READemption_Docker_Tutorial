#!/bin/bash

main(){
    readonly DOCKER_PATH=/usr/bin/docker
    readonly IMAGE_WITHOUT_TAG=reademption_101
    readonly IMAGE=reademption_101:latest
    readonly CONTAINER_NAME=reademption_container
    readonly READEMPTION_ANALYSIS_FOLDER=reademption_analysis
    readonly FTP_SOURCE=ftp://ftp.ncbi.nih.gov/genomes/archive/old_refseq/Bacteria/Salmonella_enterica_serovar_Typhimurium_SL1344_uid86645/

    #readonly MOUNT_POINT=/home/till/Documents/READemption_developing/Docker/mount_folder:/root
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
    create_running_container
    create_reademtption_folder
    download_reference_sequences


    ## inspecting the container:
    #execute_command_ls
    #execute_command_tree
    #stop_container
    #start_container
    #remove_all_containers


    #make_project_folders
    #get_read_files_from_cuba
    #unpack_read_file
    #generate_subset_of_read_file
    #download_staphylococcus_genome_and_annotation_from_ncbi
    #unzip_genome_and_annotation
    #download_reademption_image
    #show_reademption_version
    #create_reademption_project_folders
    #link_input_files_to_reademption_folder
    #run_read_alignment
    #build_coverage_files
    #run_gene_quanti
    #run_deseq

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
    wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/reference_sequences/NC_016810.fa $FTP_SOURCE/NC_016810.fna
  $DOCKER_PATH exec $CONTAINER_NAME \
    wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/reference_sequences/NC_017718.fa $FTP_SOURCE/NC_017718.fna
  $DOCKER_PATH exec $CONTAINER_NAME \
    wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/reference_sequences/NC_017719.fa $FTP_SOURCE/NC_017719.fna
  $DOCKER_PATH exec $CONTAINER_NAME \
    wget -O ${READEMPTION_ANALYSIS_FOLDER}/input/reference_sequences/NC_017720.fa $FTP_SOURCE/NC_017720.fna
}

## Inspecting

# execute a command and keep the container running
# only works when container is running
execute_command_ls(){
    $DOCKER_PATH exec $CONTAINER_NAME ls
}

# execute a command and keep the container running
# only works when container is running
execute_command_tree(){
    $DOCKER_PATH exec $CONTAINER_NAME tree $READEMPTION_ANALYSIS_FOLDER
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


#####################################

make_project_folders(){
    mkdir -p bin analyses data notes
}

get_read_files_from_cuba(){
    scp till@cuba:/havana/Sequencing_data/2017/2017-10-25_HZI_Konrad_Foerstner/all_reads/FASTQ_by_lib_trimmed/L13-S_aureus_Rep_1.fq.bz2 data
    scp till@cuba:/havana/Sequencing_data/2018/2018-04-16_HZI_Konrad_Foerstner/all_reads/FASTQ_by_lib_trimmed/L16-S_aureus_Rep_2.fq.bz2 data
}

unpack_read_file(){
    bunzip2 data/L13-S_aureus_Rep_1.fq.bz2
    bunzip2 data/L16-S_aureus_Rep_2.fq.bz2
}

generate_subset_of_read_file(){
    head -n 40000 data/L13-S_aureus_Rep_1.fq > data/L13-S_aureus_Rep_1_subset.fq
    head -n 40000 data/L16-S_aureus_Rep_2.fq > data/L16-S_aureus_Rep_2_subset.fq
}


download_staphylococcus_genome_and_annotation_from_ncbi(){
    wget \
	https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/013/425/GCF_000013425.1_ASM1342v1/GCF_000013425.1_ASM1342v1_genomic.gff.gz \
	https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/013/425/GCF_000013425.1_ASM1342v1/GCF_000013425.1_ASM1342v1_genomic.fna.gz \
	-P data
}

unzip_genome_and_annotation(){
    gunzip data/*gz
}

download_reademption_image(){
    ${SINGULARITY_PATH} build \
                bin/reademption.img \
                docker://tillsauerwein/reademption:fourthtry

}

show_reademption_version(){
    ${SINGULARITY_PATH} exec bin/reademption.img \
			reademption --version
}

create_reademption_project_folders(){
    ${SINGULARITY_PATH} exec bin/reademption.img \
			reademption create analyses/READemption_analyses
}

link_input_files_to_reademption_folder(){
    ln -s ../../../../data/GCF_000013425.1_ASM1342v1_genomic.gff analyses/READemption_analyses/input/annotations
    ln -s ../../../../data/L13-S_aureus_Rep_1_subset.fq analyses/READemption_analyses/input/reads
    ln -s ../../../../data/L16-S_aureus_Rep_2_subset.fq analyses/READemption_analyses/input/reads
    ln -s ../../../../data/GCF_000013425.1_ASM1342v1_genomic.fna analyses/READemption_analyses/input/reference_sequences
}

run_read_alignment(){
    ${SINGULARITY_PATH} exec bin/reademption.img \
			reademption align \
			-r \
			-p ${MAPPING_PROCESSES} \
			-a 95 \
			-l 20 \
			--poly_a_clipping \
			--progress \
			--fastq \
			--split \
			analyses/READemption_analyses
    echo "alignment done"
}


build_coverage_files(){
    ${SINGULARITY_PATH} exec bin/reademption.img \
                reademption coverage \
                -p $COVERAGE_PROCESSES \
                analyses/READemption_analyses

    echo "coverage done"
}

run_gene_quanti(){
    ${SINGULARITY_PATH} exec bin/reademption.img \
                reademption gene_quanti \
                -p $GENE_QUANTI_PROCESSES \
                --skip_antisense \
                analyses/READemption_analyses
    echo "gene quanti done"
}

run_deseq(){
    ${SINGULARITY_PATH} exec bin/reademption.img \
			reademption deseq \
			--libs L13-S_aureus_Rep_1_subset,L16-S_aureus_Rep_2_subset \
			--conditions replicate1,replicate2 \
			analyses/READemption_analyses
    echo "gene deseq done"
}


main $@