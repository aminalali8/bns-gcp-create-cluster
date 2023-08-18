#!/bin/bash

# Enable strict mode
set -euo pipefail

echo "🐰 Checking kubectl and gcloud..."
if command -v kubectl &>/dev/null && command -v gcloud &>/dev/null; then
    echo "🐰 You're all set to conquer the cloud! 🌩️"
else
    echo "🐰 Oops, looks like you're missing kubectl or gcloud. Time to gear up!"
    exit 1
fi

echo "🐰 Checking gcloud project configuration..."
project_id=$(gcloud config get-value project)

echo "Setting up project..."
# Check if gcloud is initiated, if not, run the first command
if ! gcloud config get-value project &>/dev/null; then
    echo "Initializing gcloud... ⚡"
    gcloud init --console-only
fi

# Ask if the user wants to create a project or use an existing one
read -p "🐰 Do you want to create a new project? (y/n): " create_new

if [ "$create_new" == "y" ]; then
    read -p "🐰 Enter the name for your new project: " new_project_name
    new_project_name_snake=$(echo "$new_project_name" | sed -E 's/ /_/g' | tr '[:upper:]' '[:lower:]')
    echo "Creating a new project: $new_project_name_snake..."
    gcloud projects create "$new_project_name_snake" --name="$new_project_name_snake"
    gcloud config set project "$new_project_name_snake"
fi

if [ "$create_new" == "n" ]; then
    read -p "🐰 Enter the existing project ID: " existing_project_id
    echo "Using existing project: $existing_project_id..."
    gcloud config set project "$existing_project_id"
fi

echo "Enabling GKE services in the project..."
gcloud services enable container.googleapis.com

# Input cluster name, region, and node size
read -p "🐰 Enter a name for your GKE cluster: " cluster_name
read -p "🐰 Enter the region for your GKE cluster (e.g., us-central1): " region
read -p "🐰 Enter the desired node size for your GKE cluster (e.g., n1-standard-2): " node_size

echo "Creating a GKE cluster..."
gcloud container clusters create "$cluster_name" --region "$region" --node-locations "$region-a" --machine-type "$node_size"

echo "Getting cluster configuration..."
# ... (previous steps)

echo "Retrieving the Service Account..."
# Check if BunnyShell service account already exists
service_account_name="bunnyshell-access"
existing_service_account_email="$service_account_name@$project_id.iam.gserviceaccount.com"
if ! gcloud iam service-accounts list --filter="email:$existing_service_account_email" --format="value(email)" &>/dev/null; then
    echo "🐰 Creating the $service_account_name Service Account..."
    gcloud iam service-accounts create "$service_account_name"
else
    echo "🐰 $service_account_name Service Account ($existing_service_account_email) already exists."
fi

# Continue with granting access and retrieving key
# ... (previous steps)

# Display additional information
current_context=$(kubectl config current-context)
cloud_region=$(kubectl config get-contexts "$current_context" | awk '{print $3}' | tail -n 1)
cluster_url=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$current_context\")].cluster.server}")
certificate=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$current_context\")].cluster.certificate-authority-data}")

echo -e "\n🐰 Additional information:"
echo "🐰 Cloud Region: $cloud_region"
echo "🐰 Cluster URL: $cluster_url"
echo "🐰 Certificate: $certificate"
echo "🐰 Project ID: $project_id"

echo "🐰 Your GKE cluster is ready for action! 🚀🔧🔍"
