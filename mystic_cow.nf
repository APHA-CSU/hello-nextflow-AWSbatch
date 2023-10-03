#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process mystic {
	cpus 2
	memory 4.GB

	output:
		path("mystic.txt")

	"""
	mystic.bash
	"""
}

process cow {
	cpus 2
	memory 4.GB

	publishDir "$params.outdir", mode: "copy", pattern: "mystic_cow.txt"

	input:
		path("mystic.txt")

	output:
		path("mystic_cow.txt")

	"""
	cow.bash mystic.txt
	"""
}

workflow {
	mystic()
	cow(mystic.out)
}
