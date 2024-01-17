terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}

# Create instance in private subnet
resource "aws_instance" "dev-instance-windows" {
  ami                         = "ami-0b1577dc927b1052f"
  instance_type               = "t2.medium"
  key_name                    = "ambience-developer-cloud"
  availability_zone           = "us-east-1a"
  tenancy                     = "default"
  subnet_id                   = aws_subnet.terraform-public-subnet.id # Private Subnet A
  ebs_optimized               = false
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.terraform-public-facing-db-sg.id # private-facing-security-group
  ]
  source_dest_check = true
  root_block_device {
    volume_size           = 50
    volume_type           = "gp2"
    delete_on_termination = true
  }
  user_data = <<EOF
<script>
net users user2 Letmein2021 /add
net users admin2 Letmein2021 /add
net localgroup Administrators admin2 /add
net localgroup "Remote Desktop Users" user2 /add
mkdir c:\temp
</script>
<powershell>
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
md -Path $env:temp\edgeinstall -erroraction SilentlyContinue | Out-Null
$Download = join-path $env:temp\edgeinstall MicrosoftEdgeEnterpriseX64.msi
Invoke-WebRequest 'http://go.microsoft.com/fwlink/?LinkID=2093437'  -OutFile $Download
Start-Process "$Download" -ArgumentList "/quiet"
cd c:\temp
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest 'https://fastdl.mongodb.org/win32/mongodb-win32-x86_64-2008plus-ssl-4.0.28-signed.msi' -OutFile mongodb-win32-x86_64-2008plus-ssl-4.0.28-signed.msi
Invoke-WebRequest 'https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.msi' -OutFile amazon-corretto-21-x64-windows-jdk.msi
Invoke-WebRequest 'https://download.microsoft.com/download/A/C/6/AC6F2802-4CC4-40B2-B333-395A4291EF29/SQLServer2016-SSEI-Eval.exe?culture=en-us&country=us' -OutFile SQLServer2016-SSEI-Eval.exe
Invoke-WebRequest 'https://aka.ms/ssmsfullsetup' -OutFile SSMS-Setup-ENU.exe
Invoke-WebRequest 'https://download.microsoft.com/download/5/6/9/56904641-5f5a-449c-a284-36c36bc45652/enu/sqljdbc_12.4.2.0_enu.zip' -OutFile sqljdbc_12.4.2.0_enu.zip
Start-Process amazon-corretto-21-x64-windows-jdk.msi -ArgumentList "/quiet" -wait
# Start-Process SQLServer2016-SSEI-Eval.exe -ArgumentList "/IACCEPTSQLSERVERLICENSETERMS", "/quiet" -wait
Start-Process mongodb-win32-x86_64-2008plus-ssl-4.0.28-signed.msi -ArgumentList ADDLOCAL="ServerService", SHOULD_INSTALL_COMPASS="0", "/quiet" -wait
Start-Process SSMS-Setup-ENU.exe -ArgumentList "/install", "/quiet" -wait
Install-WindowsFeature -Name "NET-Framework-Core" -Source "D:\Sources\SxS"
echo "User data script execution completed."
echo "[system.Diagnostics.Process]::Start("msedge","https://elixirtech1999-my.sharepoint.com/:u:/g/personal/david_elixirtech_com/ESMg87lxHmtLtcnMyNRwNRMBGjfCjVLUE4SvPeD5S4EU_A?e=0Zj4bi")" > openedge.bat
echo "[system.Diagnostics.Process]::Start("msedge", "https://elixirtech1999-my.sharepoint.com/:u:/g/personal/david_elixirtech_com/EarA3jAm-CxEsiguCe8eh48BjwEZ5y_QaFtudxainL7SdA?e=CvlPi6")" >> openedge.bat
Restart-Computer -Force
</powershell>
EOF

  tags = {
    Name = "dev-instance-linux2-terraform"
  }
}

resource "aws_vpc" "terraform-default-vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "learn-terraform-vpc"
  }
}

# How to create public / private subnet
resource "aws_subnet" "terraform-public-subnet" {
  vpc_id            = aws_vpc.terraform-default-vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "terraform-public-subnet-A"
  }
}

resource "aws_subnet" "terraform-private-subnet" {
  vpc_id            = aws_vpc.terraform-default-vpc.id
  cidr_block        = "10.2.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "terrform-private-subnet-A"
  }
}

# How to create custom route table
resource "aws_route_table" "terraform-public-route-table" {
  vpc_id = aws_vpc.terraform-default-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-default-igw.id
  }
  tags = {
    Name = "terraform-public-route-table"
  }
}

resource "aws_route_table" "terraform-private-route-table" {
  vpc_id = aws_vpc.terraform-default-vpc.id

  # Comment this out to cut cost and focus on igw only
  /*
  route {
    cidr_block = "0.0.0.0/16"
    gateway_id = aws_nat_gateway.terraform-ngw.id
  }
*/
  tags = {
    Name = "terraform-private-route-table"
  }
}


# How to create internet gateway
resource "aws_internet_gateway" "terraform-default-igw" {
  vpc_id = aws_vpc.terraform-default-vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

# How to associate route table with specific subnet
resource "aws_route_table_association" "public-subnet-rt-association" {
  subnet_id      = aws_subnet.terraform-public-subnet.id
  route_table_id = aws_route_table.terraform-public-route-table.id
}

resource "aws_route_table_association" "private-subnet-rt-association" {
  subnet_id      = aws_subnet.terraform-private-subnet.id
  route_table_id = aws_route_table.terraform-private-route-table.id
}

# Create public facing security group
resource "aws_security_group" "terraform-public-facing-db-sg" {
  vpc_id = aws_vpc.terraform-default-vpc.id
  name   = "public-facing-db-sg"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # Allow traffic from public subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-public-facing-db-sg"
  }
}

# Create private security group
resource "aws_security_group" "terraform-db-sg" {
  vpc_id = aws_vpc.terraform-default-vpc.id
  name   = "private-facing-db-sg"

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.2.0.0/16"]
    # Allow traffic from private subnets
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-private-db-sg"
  }
}

# Comment this out to cut cost and focus on igw only
/*
resource "aws_eip" "terraform-nat-eip" {
  vpc = true
   tags = {
      Name = "terraform-nat-eip"
      }
}

resource "aws_nat_gateway" "terraform-ngw" {
  allocation_id = aws_eip.terraform-nat-eip.id
  subnet_id     = aws_subnet.terraform-public-subnet.id
  tags = {
      Name = "terraform-nat-gateway"
      }
}
*/
