#!/bin/bash

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

# Define Docker registry URL
DOCKER_REGISTRY="docker.maywzh.com"
DOCKER_NAMESPACE="maywzh"
IMAGE_PREFIX="langfuse"
FILE_NAME="docker-compose.build.maywzh.yml"
docker-compose -f $FILE_NAME build

# Create a tag based on current date and time (month, day, hour, minute)
NEW_TAG=$(date +"%m%d%H%M")
echo "Using tag: $NEW_TAG"

worker_image_tag="$DOCKER_REGISTRY/$DOCKER_NAMESPACE/$IMAGE_PREFIX-langfuse-worker:$NEW_TAG"
web_image_tag="$DOCKER_REGISTRY/$DOCKER_NAMESPACE/$IMAGE_PREFIX-langfuse-web:$NEW_TAG"

if [ "$UPLOAD" = true ]; then
  # Tag the built images with the new registry path
  echo "Tagging images..."
  docker tag langfuse-langfuse-worker:latest "$worker_image_tag"
  docker tag langfuse-langfuse-web:latest "$web_image_tag"

  # Push the images to the registry
  echo "Pushing images to registry..."
  docker push "$worker_image_tag"
  docker push "$web_image_tag"

  echo "Complete! Images built and pushed with tag: $NEW_TAG"
  echo "Image names:"
  echo "$worker_image_tag"
  echo "$web_image_tag"
else
  echo "Complete! Images built locally. Use --upload to tag and push to registry."
fi

if [ "$RUN" = true ]; then
  echo "Running Docker containers in background..."
fi
