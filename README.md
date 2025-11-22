# Automated Apache Spark Cluster on AWS

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
│   └── ...
├── code/
│   ├── src/main/java/WordCount.java
│   └── pom.xml
├── data/
│   └── gen_text.py
├── scripts/
│   ├── deploy.sh
│   ├── destroy.sh
│   ├── run_benchmark.sh
│   └── clean_worker_dirs.sh
├── terraform/
│   ├── main.tf
│   └── ...
├── .gitignore
└── README.md
```

## Prerequisites
1.  **Terraform:** Installed on your local machine.
2.  **Ansible:** Installed on your local machine (`ansible`, `ansible-core`).
3.  **AWS CLI:** Installed and configured with an AWS account and credentials (`aws configure`).
4.  **Python 3:** For the data generation script.
5.  **Java & Maven:** Required to build the sample `WordCount` application.
6.  **SSH Key Pair:** An SSH key pair for accessing the EC2 instances.

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

**1. Generate and Upload Test Data**
Use the provided Python script to generate a test file and the AWS CLI to upload it to your S3 bucket.
```bash
# Generate a 100MB file
python3 data/gen_text.py 100 data/100MB_file.txt

# Upload it to S3 (replace with your bucket name)
aws s3 cp data/100MB_file.txt s3://usth-spark-project-data-tung-20251121/
```

**2. Get Node IPs**
Fetch the necessary IP addresses from the Terraform output.
```bash
cd terraform/
EDGE_NODE_IP=$(terraform output -raw edge_node_public_ip)
MASTER_PRIVATE_IP=$(terraform output -raw master_private_ip)
EDGE_NODE_PRIVATE_IP=$(terraform output -raw edge_node_private_ip)
cd ..
```

**3. Copy Files to the Edge Node**
Use `scp` to copy the application JAR and the benchmark script to the edge node.
```bash
scp -i spark-key ./code/target/spark-wordcount-1.0.jar ubuntu@$EDGE_NODE_IP:~/
scp -i spark-key ./scripts/run_benchmark.sh ubuntu@$EDGE_NODE_IP:~/
```

**4. Execute the Benchmark**
SSH into the edge node and run the benchmark script, passing the private IPs as arguments.
```bash
ssh -i spark-key ubuntu@$EDGE_NODE_IP

# On the edge node:
chmod +x run_benchmark.sh
./run_benchmark.sh $MASTER_PRIVATE_IP $EDGE_NODE_PRIVATE_IP
```
The script will submit the WordCount job for various file sizes and print the execution time for each.

## Troubleshooting and Debugging

### Checking Cluster Health
The easiest way to check the status of your workers is via the **Spark Master Web UI**.
1.  Get the master's public IP: `cd terraform && terraform output -raw master_public_ip`
2.  Open your browser and navigate to `http://<master_public_ip>:8080`.
3.  All workers should be listed with a status of **`ALIVE`**. If a worker is missing or `DEAD`, proceed with the steps below.

### Scenario 1: Worker Process Crashed (Instance is Running)
The `systemd` service is configured to restart the worker process automatically. If it fails to do so:
1.  SSH into the problematic worker node.
2.  Check the service status: `sudo systemctl status spark-worker.service`. This will show if the service is active or failed.
3.  Check the logs for errors: `journalctl -u spark-worker.service -n 100`.
4.  Manually restart the service: `sudo systemctl restart spark-worker.service`.

### Scenario 2: Worker Instance is Down or Unreachable
If an entire EC2 instance has been terminated or is unresponsive (e.g., SSH fails):
1.  **Verify in AWS Console:** Go to the EC2 dashboard in the AWS web console to confirm the instance state. You can try rebooting it from the console first.
2.  **Let Terraform Heal the Cluster:** Terraform can enforce the desired state. Simply run `terraform apply` again. It will detect the missing instance and create a new one to replace it.
    ```bash
    cd terraform/
    terraform apply -auto-approve
    ```
3.  **Re-run Ansible:** The new instance is a blank slate. Run the Ansible playbook to install Spark and configure it as a worker.
    ```bash
    cd ..
    ansible-playbook -i ansible/inventory.aws_ec2.yml ansible/playbook.yml
    ```

### Common Job Failures
*   **`OutOfMemoryError: Java heap space`**: This means the executor doesn't have enough RAM. The fix is to increase the memory allocated in the `spark-submit` command within `scripts/run_benchmark.sh`.
    *   Example: `--conf spark.executor.memory=1500m`
*   **`No space left on device`**: The instance's root disk is full. This is fixed by increasing the disk size in `terraform/main.tf` using a `root_block_device` block and redeploying the cluster.

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
```// filepath: /home/tung/USTH/CloudComputing/FinalProject/aws-spark-automation/README.md
# Automated Apache Spark Cluster on AWS

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
│   └── ...
├── code/
│   ├── src/main/java/WordCount.java
│   └── pom.xml
├── data/
│   └── gen_text.py
├── scripts/
│   ├── deploy.sh
│   ├── destroy.sh
│   ├── run_benchmark.sh
│   └── clean_worker_dirs.sh
├── terraform/
│   ├── main.tf
│   └── ...
├── .gitignore
└── README.md
```

## Prerequisites
1.  **Terraform:** Installed on your local machine.
2.  **Ansible:** Installed on your local machine (`ansible`, `ansible-core`).
3.  **AWS CLI:** Installed and configured with an AWS account and credentials (`aws configure`).
4.  **Python 3:** For the data generation script.
5.  **Java & Maven:** Required to build the sample `WordCount` application.
6.  **SSH Key Pair:** An SSH key pair for accessing the EC2 instances.

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

**1. Generate and Upload Test Data**
Use the provided Python script to generate a test file and the AWS CLI to upload it to your S3 bucket.
```bash
# Generate a 100MB file
python3 data/gen_text.py 100 data/100MB_file.txt

# Upload it to S3 (replace with your bucket name)
aws s3 cp data/100MB_file.txt s3://usth-spark-project-data-tung-20251121/
```

**2. Get Node IPs**
Fetch the necessary IP addresses from the Terraform output.
```bash
cd terraform/
EDGE_NODE_IP=$(terraform output -raw edge_node_public_ip)
MASTER_PRIVATE_IP=$(terraform output -raw master_private_ip)
EDGE_NODE_PRIVATE_IP=$(terraform output -raw edge_node_private_ip)
cd ..
```

**3. Copy Files to the Edge Node**
Use `scp` to copy the application JAR and the benchmark script to the edge node.
```bash
scp -i spark-key ./code/target/spark-wordcount-1.0.jar ubuntu@$EDGE_NODE_IP:~/
scp -i spark-key ./scripts/run_benchmark.sh ubuntu@$EDGE_NODE_IP:~/
```

**4. Execute the Benchmark**
SSH into the edge node and run the benchmark script, passing the private IPs as arguments.
```bash
ssh -i spark-key ubuntu@$EDGE_NODE_IP

# On the edge node:
chmod +x run_benchmark.sh
./run_benchmark.sh $MASTER_PRIVATE_IP $EDGE_NODE_PRIVATE_IP
```

You can also monitor the spark job via Spark Master web UI by using port-forwarding
```
ssh -i ~/.ssh/spark-key -L 8080:localhost:8080 ubuntu@<spark_master_public_IP>
```

The script will submit the WordCount job for various file sizes and print the execution time for each.

## Troubleshooting and Debugging

### Checking Cluster Health
The easiest way to check the status of your workers is via the **Spark Master Web UI**.
1.  Get the master's public IP: `cd terraform && terraform output -raw master_public_ip`
2.  Open your browser and navigate to `http://<master_public_ip>:8080`.
3.  All workers should be listed with a status of **`ALIVE`**. If a worker is missing or `DEAD`, proceed with the steps below.

### Scenario 1: Worker Process Crashed (Instance is Running)
The `systemd` service is configured to restart the worker process automatically. If it fails to do so:
1.  SSH into the problematic worker node.
2.  Check the service status: `sudo systemctl status spark-worker.service`. This will show if the service is active or failed.
3.  Check the logs for errors: `journalctl -u spark-worker.service -n 100`.
4.  Manually restart the service: `sudo systemctl restart spark-worker.service`.

### Scenario 2: Worker Instance is Down or Unreachable
If an entire EC2 instance has been terminated or is unresponsive (e.g., SSH fails):
1.  **Verify in AWS Console:** Go to the EC2 dashboard in the AWS web console to confirm the instance state. You can try rebooting it from the console first.
2.  **Let Terraform Heal the Cluster:** Terraform can enforce the desired state. Simply run `terraform apply` again. It will detect the missing instance and create a new one to replace it.
    ```bash
    cd terraform/
    terraform apply -auto-approve
    ```
3.  **Re-run Ansible:** The new instance is a blank slate. Run the Ansible playbook to install Spark and configure it as a worker.
    ```bash
    cd ..
    ansible-playbook -i ansible/inventory.aws_ec2.yml ansible/playbook.yml
    ```

### Common Job Failures
*   **`OutOfMemoryError: Java heap space`**: This means the executor doesn't have enough RAM. The fix is to increase the memory allocated in the `spark-submit` command within `scripts/run_benchmark.sh`.
    *   Example: `--conf spark.executor.memory=1500m`
*   **`No space left on device`**: The instance's root disk is full. This is fixed by increasing the disk size in `terraform/main.tf` using a `root_block_device` block and redeploying the cluster.

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