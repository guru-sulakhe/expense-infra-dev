#!/bin/bash
component=$1
environment=$2
dnf install ansible -y
pip3.9 install botocore boto3 #to connect to AWS  we need botocore,boto3
ansible-pull -i localhost, -U https://github.com/guru-sulakhe/expense-ansible-roles-tf.git main.yaml -e component=$component -e env=$environment