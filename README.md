# CA-1: Automated Cloud Deployment 

This is a project for the Dublin Business School module B9IS121 (Network Systems and Administration).

The goal of this project is to create a **fully automated CI/CD pipeline** using Infrastructure as Code (IaC) and Configuration Management tools. The pipeline automatically provisions a server on AWS, configures it, and deploys a containerized web application, all triggered by a simple `git push`.

## How to Run

This project is fully automated. To run it, you only need to:

1.  **Fork** this repository.
2.  **Create an AWS IAM User** with AdministratorAccess (or AmazonEC2FullAccess) permissions.
3.  **Create an EC2 Key Pair** in the AWS console (e.g., named `CAKey`).
4.  **Configure GitHub Secrets:** Go to your forked repository's Settings > Secrets and variables > Actions and add the following:
    * `AWS_ACCESS_KEY`: The Access Key ID from your IAM user.
    * `PWD_ACCESS_KEY_AWS`: The Secret Access Key from your IAM user.
    * `SSH_KEY_EC2`: The *entire content* of your **.pem** file (copy and paste the full text, including -----BEGIN RSA PRIVATE KEY-----...).
5.  **Push a change** to the **main** branch.

The pipeline will now run, build your server, and deploy the application automatically. The public IP of the new server will be visible in the logs of the Job 1: Terraform step.



## Implementation

Here is an explanation of what each file does and how it is implemented.

## [*ci-cd.yml*](./.github/workflows/ci-cd.yml)

**What it does:** This is the "brain" of the entire operation. It defines the CI/CD pipeline and acts as the central control node that runs all the jobs.

**Path:** .github/workflows

**How it's implemented:**
It is split into two sequential **`jobs`:**

* **Job 1: terraform**
    * This job's purpose is to provision the AWS infrastructure.
    * It uses **aws-actions/configure-aws-credentials** to log in to AWS using the `AWS_ACCESS_KEY` and `PWD_ACCESS_KEY_AWS` secrets.
    * The **working-directory: ./Terraform** parameter forces the `terraform init` and `terraform apply` commands to run in the correct sub-folder, otherwise the pipeline would fail with a "No configuration files" error.
    * The **-auto-approve** flag is added to the apply command so the pipeline doesn't stop and wait for a human to type "yes".
    * The most important step is **id: set_ip**. This step runs **terraform output -raw instance_ip** to get the new server's IP and uses **`echo "ip_address=..." >> "$GITHUB_OUTPUT"`** to save this IP as a job output. This is the "link" that makes the automation possible.

* **Job 2: ansible**
    * This job configures the server and deploys the app.
    * **needs: [terraform]** it is a very important parameter. It forces this job to *wait* until Job 1 is finished, and it also allows this job to *read* the outputs from Job 1.
    * **Set up SSH private key**: This step echo the `SSH_KEY_EC2` secret into a temporary `private.key` file. **chmod 600** is then run to give the required permisions to the KEY file.
    * **Run Ansible Playbook**: This is the main command.
        * **--inventory "${{ needs.terraform.outputs.instance_ip }},"**: This is the "dynamic inventory and it takes the IP from Job 1's. This is why the `inventory.ini` file is **not used** by the pipeline.
        * **--ssh-extra-args "-o StrictHostKeyChecking=no"**: This tells the SSH client to trust the new server's fingerprint. This is necessary because the server is brand new on every pipeline run.
    * **Verify website is running**: The *curl --fail* command pings the new IP. If the website doesn't return a "200 OK" status, the **--fail** flag will make this step fail, which correctly fails the entire pipeline. It is just a verification step.

## [*main.tf*](./Terraform/main.tf)

**What it does:** This file is the set of instructions or the plan that Terraform reads to build the AWS infrastructure.

**Path:** Terraform/

**How it's implemented:**
* **resource "aws_security_group" "CA-SG"**: This block *creates* a Security Group with a certain *inbound* and *outbounds* rules.
* **resource "aws_instance" "CA-1-Instance"**: This block defines the EC2 server.
    * ami = `"ami-033a3fad07a25c231"`: This ID is for the **Amazon Linux**

* **output "instance_ip"**: This is the **most critical block** for the automation.
    * value = **aws_instance.CA-1-Instance.public_ip**: This tells Terraform, "After you build the instance, find its `public_ip` and export it." The `.yml` file reads this value to pass to Ansible.

## [*docker_setup.yml*](./Ansible/docker_setup.yml)

**What it does:** This is the Ansible "playbook." It's the instruction manual for configuring the new and empty server.

**Path:** Ansible/

**How it's implemented:**

* **hosts: all**: This tells Ansible to run on *all* hosts provided in the inventory. Since our `.yml` file provides only one IP, this works. 

* **become: yes**: This is the equivalent of `sudo`. It's required to run any of the installation tasks.

* **ansible.builtin.dnf**: This module is used to install packages.
    * `dnf` is used because the AMI is Amazon Linux (a Red Hat-based OS).
    * It installs *docker*, *python3-pip*, and *python3-docker* (which is a required library for the Ansible `docker_container` module).
    * It is equivalent to run sudo dnf update

* **ansible.builtin.service**: This task ensures the Docker service is *started* and *enabled* (so it starts automatically on boot).
    * It is equivalent to run systemctl start / systemctl enable

* **ansible.builtin.copy**: This task copies the local `app/` folder (containing the *Dockerfile* and *index.html*) from the runner to the EC2 instance, placing it in **/home/ec2-user/app**.

* **ansible.builtin.docker_image**: This module builds the Docker image.
    * *build: path: /home/ec2-user/app*: Tells Docker where to find the `Dockerfile` on the server.
    * *force_source: true*: This is a key parameter. It forces Ansible to rebuild the image *every time*, even if the `Dockerfile` itself hasn't changed. This is how we make sure changes to `index.html` get deployed.

* **ansible.builtin.docker_container**: This module runs the container.
    * *ports: - "80:80"*: This maps the host's Port 80 to the container's Port 80, making the website public.
    * *restart_policy: always*: This ensures the container will always restart if the server reboots.

## [*Dockerfile*](./Ansible/app/Dockerfile)

**What it does:** This is the set of instructions for building the application's container image.

**Path:** app/

**How it's implemented:**

* **FROM nginx:alpine**: This is the base image. The `alpine` tag is used because it's a minimal, lightweight version of NGINX, which results in a smaller final image size and a reduced attack surface.
* **COPY index.html /usr/share/nginx/html**: This command copies the `index.html` file into the default web server directory *inside* the container, replacing the default NGINX welcome page.

## [*index.html*](./Ansible/app/index.html)

**What it does:** This is the simple, static webpage that is served to the user. Its main purpose is to prove that the entire pipeline was successful.

**Path:** /app

**How it's implemented:**
* It is a single HTML file with embedded CSS for styling.
* The content of the page explicitly lists the "Technology Stack" used (Terraform, Ansible, Docker, etc.).
* When a user accesses the public IP and sees this page, it confirms that every step—from provisioning, to configuration, to containerization, to deployment—has worked correctly.

## [*inventory.ini*](./Ansible/inventory.ini)

**Path:** /

**This file is NOT used by the automated pipeline.**

This file was only used for the initial **manual testing** (*running ansible-playbook -i inventory.ini ...* from a local laptop). In the final solution, it is replaced by the **dynamic inventory** feature in the `ci-cd.yml` file: *--inventory "${{ needs.terraform.outputs.instance_ip }},"*


## ✍️ Author

* **Guillem Angulo Hidalgo** - [GitHub](https://github.com/guillemangulo)