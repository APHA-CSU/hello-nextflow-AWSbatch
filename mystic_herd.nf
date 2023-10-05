#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process mystic {
	cpus 1
	memory 2.GB

	input:
		val cow

	output:
		tuple val(cow), path("mystic.txt")

	"""
	mystic.bash
	"""
}

process cow {
	cpus 1
	memory 2.GB

	publishDir "$params.outdir/mystic_herd", mode: "copy", pattern: "mystic_cow_*.txt"

	input:
		tuple val(cow), path("mystic.txt")

	output:
		path("mystic_cow_${cow}.txt")

	"""
	cow.bash $cow mystic.txt
	"""
}

workflow {
	Channel
	    .fromList( (1..params.herd_size).toList() )
	    .set {cowNum}

	mystic(cowNum)
	cow(mystic.out)
}
