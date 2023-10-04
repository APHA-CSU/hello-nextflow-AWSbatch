# hello-nextflow-AWSbatch

A test/example of using Nextflow's AWSbatch executor to deploy jobs to AWS batch.

Designed to run in CSU's offline SCE AWS account.

An extremely simple Nextflow pipeline creates a herd of "mystic cows". Output of `fortune` piped into `cowsay` is redirected to files and saved as `mystic_cow_x.txt`, where `x` is the cow number. 

```
 ________________________________________
/ You have Egyptian flu: you're going to \
\ be a mummy.                            /
 ----------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

The files are pushed to s3, `s3://s3-csu-offline-003/results/mystic_herd/`

## Run

To run the pipeline, execute the following from within the root of this repo, replacing `N` with the desired herd size, i.e. the number of cows/files.

`nextflow run mystic_herd.nf --herd_size N`

## AWS batch

Jobs will then be submitted to AWS batch.

Depending on the available compute resource in AWS batch a certain number of jobs will occur in parallel, e.g. if the compute instance has max vCPUs = 4 and 8GiB of memory, then four concurrent jobs can occur since our pipeline specified 1 core and 2GiB per process.
