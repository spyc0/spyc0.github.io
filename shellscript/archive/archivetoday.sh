#!/bin/bash

# Archive Website Script for Debian 12 (Bookworm)
# Uses archive.today to archive and retrieve websites for offline viewing.

ARCHIVE_URL="https://archive.today/submit/"

# Function to display usage
function usage() {
    echo "Usage: $0 <website_url>"
    echo "Example: $0 https://example.com"
    exit 1
}

# Check if curl is installed
if ! command -v curl &>/dev/null; then
    echo "Error: curl is not installed. Please install it using 'sudo apt install curl'."
    exit 1
fi

# Check if a website URL is provided
if [ "$#" -ne 1 ]; then
    usage
fi

# Get the website URL
WEBSITE_URL="$1"

# Validate the URL
if ! [[ "$WEBSITE_URL" =~ ^https?:// ]]; then
    echo "Error: Invalid URL. Make sure it starts with http:// or https://"
    usage
fi

# Submit the website to archive.today
echo "Submitting the website to archive.today..."
RESPONSE=$(curl -s -L -d "url=$WEBSITE_URL" "$ARCHIVE_URL" -w "%{url_effective}" -o /dev/null)

# Check if the response contains a valid archive.today URL
if [[ "$RESPONSE" =~ ^https://archive.today/.+ ]]; then
    echo "The website has been archived successfully."
    echo "Archived URL: $RESPONSE"
    echo "Retrieving the archived version for offline viewing..."

    # Create a local filename based on the website URL
    FILENAME=$(echo "$WEBSITE_URL" | sed 's|https\?://||; s|/|_|g').html

    # Download the archived page
    curl -s -L "$RESPONSE" -o "$FILENAME"

    if [ $? -eq 0 ]; then
        echo "The archived version has been saved locally as: $FILENAME"
    else
        echo "Error: Failed to save the archived page."
    fi
else
    echo "Error: Failed to archive the website. Please try again later."
    exit 1
fi
