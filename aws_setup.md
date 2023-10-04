# Nextflow – AWS Batch guide

## Building a custom AMI for process jobs

A custom AMI is required for compute instances in batch because the default AMIs do not have the AWS CLI installed. Nextflow uses the AWS CLI to stage working files. It is also recommended to attach a larger EBS storage volume to the image as the default (30GiB) is unlikely to be enough for real-world applications. In this test however, I just use 30GiB.

### Create a new EC2 template instance

1.	Select “Launch Instances” at the top right of the EC2 dashboard.
2.	Name the instance, e.g. “process-template”
3.	Select the correct AMI base template image. For AWS batch I believe this must be an Amazon Linux image. I used “Amazon ECS-Optimized Amazon Linux 2 (AL2) x86_64 AMI”. I think this is recommended by Nextflow.
4.	Select the instance type. From testing I think at least 8GiB of memory is required for using miniconda (see later steps), I chose m5.large.
5.	Create a key-pair (required to connect to the instance). Download and save the private key somewhere safe. Give it a name, e.g. “process-template-keypair”
6.	Create a security group and allow SSH traffic from “Anywhere” (0.0.0.0/0).
7.	Click “Launch instance”

### Connect to the template instance

In the “offline account” I’ve been unable to connect via SSH from my DEFRA laptop. Also for the amazon based AMIs I’m unable to make EC2 instance connect work. So to connect I am using SSH from AWS CloudShell in the browser/console.
1.	Search for the AWS CloudShell service in the console and click to open a new session.
2.	Create the SSH private key file from the key-pair created when creating the process template:
    - `touch  process-template-keypair.pem`
    - copy the contents of the private key file from your DEFRA laptop into this new file created in the CloudShell session. 
    - Save the file
    - `chmod 400 process-template-keypair.pem`
    
3.	Connect to the instance: 

`ssh -i "process-template-keypair.pem" ec2-user@ec2-3-253-129-246.eu-west-1.compute.amazonaws.com`


### Install dependencies in the custom AMI

The dependencies are: AWS CLI, Docker and ECS container agent. 

Docker is installed by default in the Amazon Linux 2 AMI, so we don’t need to install that and I think the same is true of the ECS container agent. So we just need to install the AWS CLI.

Nextflow says that we need to install the AWS CLI within a  self-contained package manager such as Conda. I don’t really understand their reasoning tbh.

1.	Once logged into the template instance via SSH:

```
cd $HOME
sudo yum install -y bzip2 wget
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -f -p $HOME/miniconda
$HOME/miniconda/bin/conda install -c conda-forge -y awscli
rm Miniconda3-latest-Linux-x86_64.sh
```

2. Shutdown the instance

`sudo shutdown now`

### Creating an AMI from the EC2 template instance

1.	In the EC2 dashboard in the console, under instance, tick select the newly created EC2 template instance. 
2.	On the top right select the “Actions” drop down, then “Image and  templates”, then “Create image”.
3.	Enter an image name, e.g. “hello-process-ami”.
4.	Click create image.

## Setup compute environment and job queue in AWS batch

After building the custom AMI on which our AWS batch jobs will use, we need to setup the AWS batch infrastructure. 

### Create the compute environment

1.	Got to the AWS batch service in the AWS console and click on “compute environment” on the left hand pane.
2.	Click “create” (top right)
3.	Choose EC2 (Nextflow requires EC2 not fargate – I think because of requiring more customisations than fargate offers, e.g. lager EBS, custom AMIs etc.)
4.	Name the compute environment, e.g. “hello-nextflow”.
5.	Select “managed”.
6.	Under “Service Role”, select “AWSServiceRoleForBatch” (not sure why or if this is necessary)
7.	Under “instance role” choose “ecsInstanceRole” – this has the following policies attached AmazonEC2ContainerServiceforEC2Role, AmazonS3FullAccess, ECS-CloudWatchLogs. (I’m not sure to what extend this role was customized by me, I may have done this a while ago. I’m sure that at least AmazonS3FullAccess is required.
8.	Click “continue”.
9.	Set the min, desired and max vCPUs for the compute environment (ensure that min is set to 0 so that resource is shutdown when not in use).
10.	Select desire instance types (optimal is a good option)
11.	We need to make sure that the compute environment picks up the newly created AMI. Select “additional configuration” and then click “add EC2 configuration”. Select the image type from the dropdown. In out example, we’re using “Amazon Linux 2”. In the “Image ID override” we need to copy in the AMI ID. This can be found be clicking on the AMI details under EC2 in the console.
12.	Click “Next”. The next page is “Network configuration”, these can be left as defaults. Click “Next”.
13.	Check the configuration and then click “Create compute environment”.

### Create the job queue

1.	Click “Job queues” on the left and then click “Create”.
2.	We need to link the job queue to our newly created compute environment. So select EC2.
3.	Enter a name for the job queue, e.g. “hello-nextflow”.
4.	On the connected compute environments drop-down select the name of the newly created compute environment. 
5.	Click “Create job queue”.

## File storage

We need to create some file storage, in particular for “staging” intermediary files between Nextflow processes. i.e. for the batch jobs inputs and outputs.
If we have a Nextflow script pipeline with more than one process, the files that pass through the input and output channels need to be able to get from one batch job to another. For this we use S3.

I’m also using a dedicated S3 bucket for the results and we could also use a dedicated on for input files too. 

There’s nothing special about these buckets, we can just create them under the S3 dashboard in the management console. We just need to make sure that our batch compute instances have access to S3 (I think this is done by the instance role (see above)).

I created two buckets, the work bucket, called `s3-hello-nextflow`` with a folder inside called `nextflow_env`` and a results bucket called `s3-csu-offline-003``. I think the default settings are all fine for these.


## Nextflow instance

The last thing we need to setup is an EC2 instance for running Nextflow which orchestrates the whole thing. This will need to have Nextflow installed and also the pipeline and associated nextflow.config files that we wish to run. This is the machine that effectively submits jobs to AWS batch via Nextflow.

In practice, this can actually be any machine that’s able to connect to our AWS VPC, so I think could be `wey-001`, for example.

### Create a new EC2 instance

1.	Under EC2 in the management console, click “Launch instance” as we did before when creating the custom AMI for our batch jobs. 
2.	Give the instance a name, I went for “csu-offline-001”.
3.	Select the base AMI. For this I went with “Ubuntu Server 22.04 LTS (HVM), SSD Volume Type” and x86 architecture. For some reason only in ubuntu was I able to connect with EC2-instance-connect, also it made sense to use ubuntu as this is what out dev machines are in the SCE.
4.	I used t2.micro as this is free, also this machine isn’t actually doing any heavy lifting, it’s just submitting jobs so doesn’t need to be big.
5.	Under “Key pair”, I selected “proceed without key pair” as EC2 instance connect doesn’t require a key pair.
6.	Under security group, I selected two, “launch-wizard-2” and “default”, I think I’ve setup launch-wizard-2 to have an additional security group rule which is to accept inbound SSH traffic on port 22 from the IP range for the EC2-instance-connect server in eu-west-1 region, which is found in the IP-ranges json.
7.	For storage select 30GB as I think this is in the free range.

### EC2 instance connect IAM policy

We need to create a new IAM policy and link it to our IAM user to enable EC2 instance connect on the new ubuntu EC2 VM. 
1.	Search for IAM policies in the console and click “Create policy” (top right).
2.	Select “JSON” top right.
3.	Copy the following policy into the box:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2-instance-connect:SendSSHPublicKey",
            "Resource": [
                "arn:aws:ec2:eu-west-1:982622767822:instance/i-0c1e9e4b50ab4aa32"
            ],
            "Condition": {
                "StringEquals": {
                    "ec2:osuser": "ubuntu"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "ec2:DescribeInstances",
            "Resource": "*"
        }
    ]
} 
```

4.	Click “Next”, name the policy, e.g. “ubuntu-ec2-instance-connect-policy” and then click “Create policy”.
5.	Then when back to the “Policies” page, select the newly create policy and click the “Actions” drop-down and then select “Attach” to attach a user to the policy.
6.	On the subsequent page, attach the administrator user, as we are running these services as administrator.

### Connect to the new instance

We should now be able to connect to the new EC2 instance in the console via EC2 instance connect.

1.	Navigate to the EC2 page in the AWS console, and start the newly created instance.
2.	Right click on the newly created instance and click “Connect”.
3.	Ensure we are using “EC2 instance connect”, the user name should b already set as “ubuntu” this is the correct default user for our new ubuntu EC2 instance. 
4.	Click “Connect”. We should be connected to a terminal in our new EC2 instance.




### Build and upload the Docker image to ECR

We need a Docker container for our processes to run on our compute environment in AWS batch. 

I’ve created a Dockerfile for a test pipeline which is currently at APHA-CSU/hello-nextflow-AWSbatch (github.com). We can clone this repo and build the docker image (need to have Docker installed on the EC2).

*Note: we only need Docker installed for this one associated setup process, it’s not needed for actually running the pipeline at all. It just makes sense to do this from this EC2 since it’s in the AWS VPC and this has access to ECR.

1.	Clone the repo.
2.	Run `docker build . -t mystic_cow`
3.	We then need to create an ECR registry and upload our Docker image. Go to ECR in AWS console and click “Create repository”, name the repo, e.g. “mystic-cow” and then click create.
4.	We then need to upload our image to the ECR registry. Back in our EC2:

```
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 982622767822.dkr.ecr.eu-west-1.amazonaws.com
docker tag mystic-cow:latest 982622767822.dkr.ecr.eu-west-1.amazonaws.com/mystic-cow:latest
docker push 982622767822.dkr.ecr.eu-west-1.amazonaws.com/mystic-cow:latest
```

### Install Nextflow

1.	Install the Java runtime environment: 

`sudo apt-get install openjdk-17-jdk`

2.	Install Nextflow:

`curl -s https://get.nextflow.io | bash`

3.	Move nextflow executable to be on your path:

`sudo mv nextflow /usr/local/bin/.`

4.	Test Nextflow installation:
“nextflow run hello”

## The Nextflow pipeline

At this point the repo can simply be cloned and, in theory if we run `nextflow run mystic_cow.nf --herd_size 6` , this should run the nextflow pipeline, submitting jobs to AWS batch.

The important things to note in the code are:

* The workdir is set to “"s3://s3-hello-nextflow/nextflow_env/" in nextflow.config. (line 2) this is for the intermediary files.
* The “nf-amazon” plugin (lines 4-6) in nextflow.config.
* The parameters for the processes set in the nextflow.config. These are the executor, set to “awsbatch” (line 9) (this is the key bit that tells nextflow not to run the jobs locally and instead to run them in AWS batch, the queue is set to our AWS batch job queue “hello-nextflow” (line 10), and the container is set to the ECR URI of our docker container for the jobs (line 11).
* Importantly the jobs need to know where the AWS CLI is installed to in our custom AMI, the path of this is set in the nextflow.config (line 16)
* Also the region is set on line 18.
Aside from this, the nextflow pipeline, i.e. the main .nf file is exactly the same is it might be if we were to execute locally.
