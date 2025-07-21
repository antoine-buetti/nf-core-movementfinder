process GET_ALL_MOVING_FRAMES {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'ubuntu:22.04' }"

    input:
    tuple val(meta), path(movement_data_frames), path(frames_dir), path(traceDiff_frames_dir)
    val thresh_moving

    output:
    tuple val(meta), path("moving_frames_*"), emit: moving_frames_dir
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir moving_frames_${frames_dir}
    awk '{counter++; if(\$1>${thresh_moving}) {printf("cp ${frames_dir}/%08d.jpg ${traceDiff_frames_dir}/traceDiffFrame_%08d  moving_frames_${frames_dir} \\n"),counter,counter}}' ${movement_data_frames} > tmp.sh
    bash tmp.sh

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n1 | sed 's/.*awk //' | sed 's/ .*//')
    END_VERSIONS
    """
}