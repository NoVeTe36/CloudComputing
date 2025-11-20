output "master_public_ip" {
  description = "The public IP address of the Spark master node."
  value       = aws_instance.spark_master.public_ip
}

output "worker_public_ips" {
  description = "The public IP addresses of the Spark worker nodes."
  value       = aws_instance.spark_worker.*.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the master node."
  value       = "ssh -i ../spark-key ubuntu@${aws_instance.spark_master.public_ip}"
}

output "edge_node_ssh_command" {
  description = "Command to SSH into the edge node for job submission."
  value       = "ssh -i ../spark-key ubuntu@${aws_instance.spark_edge_node.public_ip}"
}