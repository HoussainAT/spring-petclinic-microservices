#!/bin/bash
set -euxo pipefail
exec > /var/log/user_data.log 2>&1

# ── System update ──────────────────────────────────────────────────────────────
yum update -y

# ── Docker ────────────────────────────────────────────────────────────────────
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# ── Docker Compose v2 ─────────────────────────────────────────────────────────
COMPOSE_VERSION="v2.24.6"
curl -fsSL \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# ── Java 17 + Maven (needed to build + produce Docker images) ─────────────────
yum install -y java-17-amazon-corretto-devel git

# Increase Maven memory for builds on t3.large
export MAVEN_OPTS="-Xmx4g -XX:MaxMetaspaceSize=512m"

# ── Clone the forked repo ─────────────────────────────────────────────────────
cd /opt
git clone https://github.com/HoussainAT/spring-petclinic-microservices.git
cd spring-petclinic-microservices

# ── Build all service JARs ────────────────────────────────────────────────────
./mvnw clean package -DskipTests \
  2>&1 | tee /var/log/mvn-package.log

# ── Build Docker images via Spring Boot buildpack ────────────────────────────
./mvnw spring-boot:build-image -DskipTests \
  2>&1 | tee /var/log/mvn-build-image.log

# ── Launch the stack ──────────────────────────────────────────────────────────
docker-compose up -d \
  2>&1 | tee /var/log/docker-compose.log

echo "=== user_data finished at $(date) ==="
