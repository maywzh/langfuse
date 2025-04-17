#!/bin/bash
# filepath: /Users/wangzmei/Workspace/tvs-agent-registry/build_and_push.sh

# Exit immediately if a command exits with a non-zero status
set -e

UPLOAD=false
RUN=false
ENV_FILE=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --upload) UPLOAD=true ;;
  --run) RUN=true ;;
  --env-json=*)
    ENV_FILE="${1#*=}"
    ;;
  *)
    echo "Unknown parameter: $1"
    exit 1
    ;;
  esac
  shift
done

echo "Building Docker images..."
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
  echo "Using environment file: $ENV_FILE for build"
  if [[ "$ENV_FILE" == *.json ]]; then
    # Handle JSON file
    export $(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' "$ENV_FILE" | xargs)
  else
    # Handle .env file
    export $(cat "$ENV_FILE" | xargs)
  fi
fi
docker-compose -f docker-compose.build.tesla.yml build

# Create a tag based on current date and time (month, day, hour, minute)
NEW_TAG=$(date +"%m%d%H%M")
echo "Using tag: $NEW_TAG"

if [ "$UPLOAD" = true ]; then
  # Tag the built images with the Tesla registry path
  echo "Tagging images..."
  docker tag langfuse-langfuse-worker:latest "nyuwa-user-docker-local.arf.tesla.cn/nyuwa-ns-voc/langfuse-prd-langfuse-worker:$NEW_TAG"
  docker tag langfuse-langfuse-web:latest "nyuwa-user-docker-local.arf.tesla.cn/nyuwa-ns-voc/langfuse-prd-langfuse-web:$NEW_TAG"

  # Push the images to the registry
  echo "Pushing images to registry..."
  docker push "nyuwa-user-docker-local.arf.tesla.cn/nyuwa-ns-voc/langfuse-prd-langfuse-worker:$NEW_TAG"
  docker push "nyuwa-user-docker-local.arf.tesla.cn/nyuwa-ns-voc/langfuse-prd-langfuse-web:$NEW_TAG"

  echo "Complete! Images built and pushed with tag: $NEW_TAG"
  echo "Image names:"
  echo "nyuwa-user-docker-local.arf.tesla.cn/nyuwa-ns-voc/langfuse-prd-langfuse-worker:$NEW_TAG"
  echo "nyuwa-user-docker-local.arf.tesla.cn/nyuwa-ns-voc/langfuse-prd-langfuse-web:$NEW_TAG"
else
  echo "Complete! Images built locally. Use --upload to tag and push to registry."
fi

if [ "$RUN" = true ]; then
  echo "Running Docker containers in background..."
fi
