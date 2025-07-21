process GET_FRAMES {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'ubuntu:22.04' }"

    input:
    tuple val(meta), path(video)

    output:
    tuple val(meta), path("*_frames"), emit: frames_dir
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    apt-get update && apt-get install -y procps mplayer

    mkdir "${prefix}_frames"
    mplayer -nosound -vo jpeg:outdir="${prefix}_frames" -speed 100 "$video" -benchmark

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mplayer: \$(mplayer -version 2>&1 | head -n1 | sed 's/.*MPlayer //' | sed 's/ .*//')
    END_VERSIONS
    """
}