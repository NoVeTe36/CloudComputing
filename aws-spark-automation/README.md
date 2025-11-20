# gcp-spark-automation

## Overview
This project automates the deployment of an Apache Spark cluster on Google Cloud Platform (GCP) using Ansible and Terraform. It provides a streamlined process for provisioning infrastructure and configuring Spark components, making it easier to set up and manage Spark clusters in the cloud.

## Architecture
The project consists of the following main components:
- **Terraform**: Used for provisioning GCP resources such as Compute Engine instances, VPC, and firewall rules.
- **Ansible**: Used for configuring the Spark cluster, including the Spark master and worker nodes.
- **Scripts**: Shell scripts to automate deployment, destruction, and restarting of the Spark cluster.

## Project Structure
```
gcp-spark-automation
├── ansible
│   ├── roles
│   │   ├── common
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   ├── spark-master
│   │   │   └── tasks
│   │   │       └── main.yml
│   │   └── spark-worker
│   │       └── tasks
│   │           └── main.yml
│   ├── ansible.cfg
│   ├── inventory.gcp.yml
│   └── playbook.yml
├── scripts
│   ├── deploy.sh
│   ├── destroy.sh
│   └── restart.sh
├── terraform
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
└── README.md
```

## Setup Instructions
1. **Prerequisites**:
   - Ensure you have Terraform and Ansible installed on your local machine.
   - Set up a Google Cloud account and configure the Google Cloud SDK.

2. **Configure Terraform**:
   - Modify the `variables.tf` file in the `terraform` directory to customize resource sizes, counts, and other parameters as needed.

3. **Deploy the Spark Cluster**:
   - Run the `deploy.sh` script located in the `scripts` directory. This will provision the necessary GCP resources and configure the Spark cluster.

   ```bash
   ./scripts/deploy.sh
   ```

4. **Access the Spark Master**:
   - After deployment, you can access the Spark master UI using the external IP address provided in the Terraform outputs.

## Usage Guidelines
- To terminate all resources created by Terraform, run the `destroy.sh` script:

   ```bash
   ./scripts/destroy.sh
   ```

- To restart the Spark cluster, use the `restart.sh` script, which will destroy existing resources and redeploy them:

   ```bash
   ./scripts/restart.sh
   ```

## Conclusion
This project simplifies the process of deploying and managing an Apache Spark cluster on GCP. By leveraging Terraform and Ansible, users can quickly set up a scalable and efficient Spark environment for their data processing needs.