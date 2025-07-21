process MOVEMENT_SPOTTER {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'ubuntu:22.04' }"

    input:
    tuple val(meta), path(frames_dir)
    val fuzz

    output:
    tuple val(meta), path("data_*.dat")    , emit: data_list
    tuple val(meta), path("traceDiff_*")   , emit: traceDiff_frames_dir
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    apt-get update && apt-get install -y procps imagemagick

    N=\$(ls ${frames_dir}/*.jpg | wc | awk '{print \$1}')
    for i in `seq 1 \$((\$N-1))`; do # last frame -2 because compare 2 a 2
    cmd=\$(printf "compare -metric AE -fuzz ${fuzz}%% ${frames_dir}/%08d.jpg ${frames_dir}/%08d.jpg traceDiffFrame_%08d 2>> data_${frames_dir}.dat ; echo >> data_${frames_dir}.dat \\n" \$i \$((\$i+1)) \$i )
    echo \$cmd >> tmp.sh
    done
    bash tmp.sh 

    # move all diff pixel frames to dedicated directory:
    mkdir traceDiff_${frames_dir}
    mv  traceDiffFrame_* traceDiff_${frames_dir} 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        imagemagick: \$(convert -version | head -n1 | sed 's/.*ImageMagick //' | sed 's/ .*//')
    END_VERSIONS
    """
}