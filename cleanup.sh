#!/bin/bash

# Enable strict mode
set -euo pipefail

echo "🐰 Checking gcloud project configuration..."
project_id=$(gcloud config get-value project)

# Prompt user for confirmation
read -p "🐰 Are you sure you want to delete all resources created by the main script? (y/n): " confirm

if [ "$confirm" == "y" ]; then
    # Delete GKE cluster
    read -p "🐰 Enter the name of the GKE cluster to delete: " cluster_name
    read -p "🐰 Enter the region of the GKE cluster: " region
    gcloud container clusters delete "$cluster_name" --region "$region" --quiet

    # Delete Google Service Account
    service_account_name="bunnyshell-access"
    gcloud iam service-accounts delete "$service_account_name@$project_id.iam.gserviceaccount.com" --quiet

    # Delete Google Service Account Key
    rm -f gsa-key.json

    echo "🐰 Cleanup complete! All resources created by the main script have been deleted."
else
    echo "🐰 Cleanup aborted. No resources were deleted."
fi