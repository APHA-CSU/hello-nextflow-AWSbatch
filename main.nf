#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process mysticCow {
	cpus 2
	memory 4.GB

	publishDir "$params.outdir", mode: "copy"

	output:
		path("mystic_cow.txt")

	"""
	mystic_cow.bash
	"""
}

workflow {
	mysticCow()
}
