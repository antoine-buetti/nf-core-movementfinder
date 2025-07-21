/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { GET_FRAMES             } from '../modules/local/get_frames/main'
include { MOVEMENT_SPOTTER       } from '../modules/local/movement_spotter/main'
include { GET_ALL_MOVING_FRAMES  } from '../modules/local/get_all_moving_frames/main'
include { PLOT                   } from '../modules/local/plot/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_movementfinder_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MOVEMENTFINDER {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // Print pipeline info
    //
    log.info """\
        Movement Finder in Fixed-camera Videos
        ===================================
        input        : ${params.input}
        outdir       : ${params.outdir}
        fuzz         : ${params.fuzz}
        thresh_moving: ${params.thresh_moving}

        Example usage: nextflow run main.nf --input your_folder_with_mp4_video_files --outdir results --fuzz 25 --thresh_moving 0
        Output: "plot_...png" showing a profile of the video and how much movement was detected. "moving_frames_..." containing the snapshots extracted where the movement occurred, and the pixels that were tracked.

        The parameter fuzz 15% means that pixels within 25% color difference are treated as equal. You can increase it to make it even more tolerant (a lower fuzz is more sensitive but more prone to noise).
        ===================================
        """
        .stripIndent()

    //
    // MODULE: Extract frames from videos
    //
    GET_FRAMES (
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(GET_FRAMES.out.versions.first())

    //
    // MODULE: Detect movement between frames
    //
    MOVEMENT_SPOTTER (
        GET_FRAMES.out.frames_dir,
        params.fuzz
    )
    ch_versions = ch_versions.mix(MOVEMENT_SPOTTER.out.versions.first())

    //
    // MODULE: Extract frames with movement
    //
    // Combine the outputs for GET_ALL_MOVING_FRAMES
    ch_combined_for_moving_frames = MOVEMENT_SPOTTER.out.data_list
        .join(GET_FRAMES.out.frames_dir)
        .join(MOVEMENT_SPOTTER.out.traceDiff_frames_dir)

    GET_ALL_MOVING_FRAMES (
        ch_combined_for_moving_frames,
        params.thresh_moving
    )
    ch_versions = ch_versions.mix(GET_ALL_MOVING_FRAMES.out.versions.first())

    //
    // MODULE: Create movement plot
    //
    PLOT (
        MOVEMENT_SPOTTER.out.data_list
    )
    ch_versions = ch_versions.mix(PLOT.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'movementfinder_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
