 Automated Apache Spark Cluster on AWS

## Overview
This project provides a fully automated solution for deploying, managing, and scaling an Apache Spark cluster on Amazon Web Services (AWS). It leverages Infrastructure as Code (IaC) with **Terraform** to provision the cloud resources and configuration management with **Ansible** to install and configure the Spark environment.

The primary goal is to create a repeatable, production-ready Spark cluster that can be deployed or destroyed with a single command, complete with best practices for security, networking, and data access.

## Architecture
The entire infrastructure is provisioned within a custom AWS VPC for network isolation.

*   **Infrastructure (Terraform):**
    *   **VPC & Networking:** A dedicated VPC with a public subnet, Internet Gateway, and route tables to enable internet access for all nodes.
    *   **EC2 Instances:** Three distinct roles are provisioned:
        *   **1 Spark Master:** Coordinates cluster activities.
        *   **N Spark Workers:** A configurable number of worker nodes that execute Spark tasks.
        *   **1 Edge Node:** A client machine for submitting jobs via `spark-submit`.
    *   **Security:** A single Security Group allows SSH from anywhere and all internal traffic between cluster nodes, ensuring secure and seamless communication.
    *   **Data & Access Control (IAM):** An S3 bucket is created for persistent data storage. An IAM Role with S3 access is attached to all EC2 instances, allowing Spark to read from and write to S3 without storing credentials on the machines.

*   **Configuration (Ansible):**
    *   **Dynamic Inventory:** Uses the `aws_ec2` plugin to automatically discover and group instances based on their tags.
    *   **Roles:**
        *   `common`: Installs Java, Scala, and sets up the Spark distribution on all nodes.
        *   `spark-master`: Configures and starts the Spark Master `systemd` service.
        *   `spark-worker`: Configures and starts the Spark Worker `systemd` service on all worker nodes.
    *   **Service Management:** Deploys `systemd` service files to ensure Spark daemons run automatically on boot and are managed as resilient system services.

## Project Structure
```
aws-spark-automation/
├── ansible/
│   ├── roles/
│   │   ├── common/
│   │   │   ├── tasks/main.yml
│   │   │   └── templates/spark-env.sh.j2
│   │   ├── spark-master/
│   │   │   ├── tasks/main.yml
│   │   │   └── templates/spark-master.service.j2
│   │   └── spark-worker/
│   │       ├── tasks/main.yml
│   │       └── templates/spark-worker.service.j2
│   ├── inventory.aws_ec2.yml
│   └── playbook.yml
├── code/
│   ├── src/main/java/WordCount.java
│   └── pom.xml
├── scripts/
│   ├── deploy.sh
│   ├── destroy.sh
│   ├── run_benchmark.sh
│   └── clean_worker_dirs.sh
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── .gitignore
└── README.md
```

## Prerequisites
1.  **Terraform:** Installed on your local machine.
2.  **Ansible:** Installed on your local machine (`ansible`, `ansible-core`).
3.  **AWS CLI:** Installed and configured with an AWS account and credentials (`aws configure`).
4.  **Java & Maven:** Required to build the sample `WordCount` application.
5.  **SSH Key Pair:** An SSH key pair for accessing the EC2 instances.

## Setup and Deployment

**1. Clone the Repository**
```bash
git clone <your-repo-url>
cd aws-spark-automation
```

**2. Generate SSH Key Pair**
If you don't have one, create an SSH key pair. This will create `spark-key` (private) and `spark-key.pub` (public).
```bash
ssh-keygen -t rsa -b 4096 -f spark-key -N ""
```

**3. Configure Infrastructure Variables**
Modify `terraform/terraform.tfvars` to customize your deployment.
```hcl
// terraform/terraform.tfvars
aws_region      = "ap-southeast-1"
ami_id          = "ami-00d8fc944fb171e29" // Ubuntu 22.04 for ap-southeast-1
instance_type   = "t3.small"
worker_count    = 4
key_name        = "spark-cluster-key"
public_key_path = "../spark-key.pub"
```

**4. Build the Spark Application**
Package the sample `WordCount` application into a JAR file.
```bash
cd code/
mvn clean package
cd ..
```

**5. Deploy the Cluster**
Run the `deploy.sh` script. This single command will provision all AWS resources with Terraform and then configure them with Ansible.
```bash
bash scripts/deploy.sh
```
The process will take several minutes. Upon completion, your Spark cluster will be running.

## Usage: Running a WordCount Job

**1. Get Node IPs**
Fetch the necessary IP addresses from the Terraform output.
```bash
cd terraform/
# Get the public IP for the edge node
EDGE_NODE_IP=$(terraform output -raw edge_node_public_ip)
# Get the private IPs for the master and edge nodes
MASTER_PRIVATE_IP=$(terraform output -raw master_private_ip)
EDGE_NODE_PRIVATE_IP=$(terraform output -raw edge_node_private_ip)
cd ..
```

**2. Copy Files to the Edge Node**
Use `scp` to copy the application JAR and the benchmark script to the edge node.
```bash
scp -i spark-key ./code/target/spark-wordcount-1.0.jar ubuntu@$EDGE_NODE_IP:~/
scp -i spark-key ./scripts/run_benchmark.sh ubuntu@$EDGE_NODE_IP:~/
```

**3. Execute the Benchmark**
SSH into the edge node and run the benchmark script, passing the private IPs as arguments.
```bash
ssh -i spark-key ubuntu@$EDGE_NODE_IP

# On the edge node:
chmod +x run_benchmark.sh
./run_benchmark.sh $MASTER_PRIVATE_IP $EDGE_NODE_PRIVATE_IP
```
The script will submit the WordCount job for various file sizes and print the execution time for each.

## Cluster Management Scripts

*   **`scripts/deploy.sh`**: Provisions and configures the entire cluster.
*   **`scripts/destroy.sh`**: Destroys all AWS resources created by Terraform. **Use with caution.**
    ```bash
    bash scripts/destroy.sh
    ```
*   **`scripts/clean_worker_dirs.sh`**: SSHes into each worker and clears the temporary `/opt/spark/work/` directory. Useful for manual cleanup.
    ```bash
    bash scripts/clean_worker_dirs.sh
    ```