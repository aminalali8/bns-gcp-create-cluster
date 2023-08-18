#!/bin/bash

echo "🐰 Checking kubectl and gcloud..."
if command -v kubectl &>/dev/null && command -v gcloud &>/dev/null; then
    echo "🐰 You're all set to conquer the cloud! 🌩️"
else
    echo "🐰 Oops, looks like you're missing kubectl or gcloud. Time to gear up!"
fi

echo "🐰 Checking gcloud project configuration..."
# Check if gcloud is initiated, if not, run the first command
if ! gcloud config get-value project &>/dev/null; then
    echo "🐰 Initializing gcloud... ⚡"
    gcloud init --console-only
fi

echo "🐰 Setting up project..."
# Ask if the user wants to use the preset configuration of gcloud
read -p "🐰 Do you want to use the preset gcloud configuration? (y/n): " use_preset_config

if [ "$use_preset_config" == "y" ]; then
    echo "🐰 Using the preset gcloud configuration..."
else
    # Ask if the user wants to create a project or use an existing one
    read -p "🐰 Do you want to create a new project? (y/n): " create_new

    if [ "$create_new" == "y" ]; then
        read -p "🐰 Enter the name for your new project: " new_project_name
        new_project_name_snake=$(echo "$new_project_name" | sed -E 's/ /_/g' | tr '[:upper:]' '[:lower:]')
        echo "🐰 Creating a new project: $new_project_name_snake..."
        gcloud projects create "$new_project_name_snake" --name="$new_project_name_snake"
        gcloud config set project "$new_project_name_snake"
    fi

    if [ "$create_new" == "n" ]; then
        read -p "🐰 Enter the existing project ID: " existing_project_id
        echo "🐰 Using existing project: $existing_project_id..."
        gcloud config set project "$existing_project_id"
    fi
fi

echo "🐰 Checking if Containers API is enabled..."
# Check if the Containers API is enabled
if ! gcloud services list --project "$(gcloud config get-value project)" --format="value(serviceConfig.name)" | grep -q "container.googleapis.com"; then
    echo "🐰 Warning: The Containers API is not enabled."
    read -p "🐰 Do you want to enable the Containers API? (y/n): " enable_api

    if [ "$enable_api" == "y" ]; then
        echo "🐰 Enabling the Containers API..."
        gcloud services enable container.googleapis.com --project "$(gcloud config get-value project)"
        echo "You may have to adjust your resource limits and enable billing based on your subscription."
        echo "Go to https://console.cloud.google.com"
        echo "From the Navigation menu on the top left, browse to Compute->Kubernetes Engine."
        echo "Click enable billing. Click Set Account."
    else
        echo "🐰 The Containers API must be enabled to proceed."
        exit 1
    fi
fi

# If the Containers API is enabled
if gcloud services list --project "$(gcloud config get-value project)" --format="value(serviceConfig.name)" | grep -q "container.googleapis.com"; then
    echo "🐰 Containers API is enabled! You're ready to rock and roll!"
fi

# Input cluster name and region
read -p "🐰 Enter a name for your GKE cluster: " cluster_name
read -p "🐰 Enter the region for your GKE cluster (e.g., us-central1): " region
read -p "🐰 Enter the desired node size for your GKE cluster (e.g., n1-standard-2): " node_size

echo "🐰 Creating a GKE cluster..."
# Tell GKE to create the cluster with the specified node size
gcloud container clusters create "$cluster_name" --region "$region" --machine-type "$node_size"

echo "🐰 Getting cluster configuration..."
# Get cluster credentials for kubectl
gcloud container clusters get-credentials "$cluster_name" --region "$region" --project "$(gcloud config get-value project)"

echo "🐰 Retrieving the Bunnyshell Service Account..."
# Check if BunnyShell service account already exists
service_account_name="bunnyshell-access"
if ! gcloud iam service-accounts list --filter="email:bunnyshell-access@$(gcloud config get-value project).iam.gserviceaccount.com" --format="value(email)" &>/dev/null; then
    echo "🐰 Creating the BunnyShell Service Account..."
    gcloud iam service-accounts create "$service_account_name"
else
    echo "🐰 BunnyShell Service Account ($existing_service_account_email) already exists."
fi

echo "🐰 Granting the Service Account access to your cluster..."
# Grant Service Account access to the cluster
gcloud projects add-iam-policy-binding "$(gcloud config get-value project)" \
    --member="serviceAccount:$service_account_name@$(gcloud config get-value project).iam.gserviceaccount.com" \
    --role=roles/container.admin

echo "🐰 Retrieving the Google Service Account Key..."
# Create Google Service Account Key
gcloud iam service-accounts keys create gsa-key.json \
    --iam-account="$service_account_name@$(gcloud config get-value project).iam.gserviceaccount.com"

# Display additional information
cloud_region=$(kubectl config get-contexts "$(kubectl config current-context)" | awk '{print $3}' | tail -n 1)
cluster_url=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$(kubectl config current-context)\")].cluster.server}")
certificate=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$(kubectl config current-context)\")].cluster.certificate-authority-data}")
project_id="$(gcloud config get-value project)"

echo -e "\n🐰 Additional information:"
echo "🐰 Cloud Region: $cloud_region"
echo "🐰 Cluster URL: $cluster_url"
echo "🐰 Certificate: $certificate"
echo "🐰 Project ID: $project_id"

echo "🐰 Your GKE cluster is ready for action! 🚀🔧🔍"
