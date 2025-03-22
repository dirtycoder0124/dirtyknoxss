#!/bin/bash

# Knoxss API Key (Replace with your actual API key)
API_KEY="KNOXSS_API_HERE"

# Knoxss API Endpoint
API_URL="https://api.knoxss.pro"

# Input file containing target URLs
INPUT_FILE="$1"

# Output log file
OUTPUT_FILE="knoxss_results.txt"

# Remaining URLs if the script is interrupted
TODO_FILE="knoxss_remaining.todo"

# Number of parallel requests (adjust based on system performance)
THREADS=20

# Lock file for safely updating API Call count
LOCK_FILE="/tmp/knoxss_lock"

# Temp file to track progress
PROGRESS_FILE="/tmp/knoxss_progress.txt"
> "$PROGRESS_FILE"  # Clear previous progress

# Trap SIGINT (CTRL+C) and SIGTERM to save remaining URLs
trap 'save_remaining_urls; exit 1' SIGINT SIGTERM

# Function to save remaining URLs when script stops unexpectedly
save_remaining_urls() {
    comm -23 <(sort "$INPUT_FILE") <(sort "$PROGRESS_FILE") > "$TODO_FILE"

    if [[ -s "$TODO_FILE" ]]; then
        echo -e "\n\e[31m[!] Script stopped. Saving unfinished URLs...\e[0m"
        echo -e "\e[33mRemaining URLs saved in $TODO_FILE\e[0m"
    else
        rm -f "$TODO_FILE"  # Remove the .todo file if it's empty (script finished successfully)
    fi
}

# Check if input file is provided
if [[ -z "$INPUT_FILE" ]]; then
    echo "Usage: $0 <url_list.txt>"
    exit 1
fi

# Check if input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Read the number of targets
TARGET_COUNT=$(wc -l < "$INPUT_FILE")
echo -e "\e[34mCalling KNOXSS API for $TARGET_COUNT targets (Running $THREADS threads)...\e[0m"
echo "Calling KNOXSS API for $TARGET_COUNT targets..." > "$OUTPUT_FILE"

# Function to URL encode
url_encode() {
    echo -n "$1" | jq -sRr @uri
}

# Function to process each URL (runs in parallel)
scan_target() {
    local url="$1"
    local encoded_url
    encoded_url=$(url_encode "$url")  # Encode the URL

    echo -e "\e[36m[+] Scanning: $url\e[0m"

    # Send request to Knoxss API
    local response
    response=$(curl -s "$API_URL" -d "target=$encoded_url" -H "X-API-KEY: $API_KEY")

    # Ensure the response is valid JSON before using jq
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo -e "\e[31m[ ERR! ] - (GET) $url  KNOXSS ERR: Invalid API Response\e[0m"
        echo "[ ERR! ] - (GET) $url  KNOXSS ERR: Invalid API Response" >> "$OUTPUT_FILE"
        return
    fi

    # Extract response fields safely
    local xss
    xss=$(echo "$response" | jq -r '.XSS // "none"')
    local poc
    poc=$(echo "$response" | jq -r '.PoC // "none"')
    local error
    error=$(echo "$response" | jq -r '.Error // "none"')
    local api_call
    api_call=$(echo "$response" | jq -r '."API Call" // "0/5000"')

    # Use lock to update API call count safely
    (
        flock -x 200  # Lock to prevent multiple processes writing at once
        echo "$api_call" > /tmp/last_api_call.txt
    ) 200>"$LOCK_FILE"

    # Save processed URL
    echo "$url" >> "$PROGRESS_FILE"

    # Determine the result type
    if [[ "$error" != "none" ]]; then
        echo -e "\e[31m[ ERR! ] - (GET) $url  KNOXSS ERR: $error\e[0m"
        #echo "[ ERR! ] - (GET) $url  KNOXSS ERR: $error"
    elif [[ "$xss" == "true" ]]; then
        echo -e "\e[32m[ XSS! ] - (GET) $poc [$api_call]\e[0m"
        echo "[ XSS! ] - (GET) $poc [$api_call]" >> "$OUTPUT_FILE"
    else
        echo -e "\e[33m[ NONE ] - (GET) $url [$api_call]\e[0m"
    fi
}

export -f scan_target url_encode save_remaining_urls  # Export functions for parallel
export API_URL API_KEY OUTPUT_FILE LOCK_FILE PROGRESS_FILE  # Export variables

# Run scan in parallel
cat "$INPUT_FILE" | parallel -j "$THREADS" scan_target {}

# Check if script completed successfully
save_remaining_urls  # This will remove the .todo file if nothing is left

# Read the last stored API Call value safely
if [[ -f /tmp/last_api_call.txt ]]; then
    LAST_API_CALL=$(cat /tmp/last_api_call.txt)
else
    LAST_API_CALL="0/5000"
fi

# Display API call summary
RESET_TIME=$(date -d "$(date) +1 hour" +"%Y-%m-%d %H:%M")
echo ""
echo -e "\e[34mAPI calls made so far today - $LAST_API_CALL (API Limit Reset Time: $RESET_TIME)\e[0m"
echo ""
echo -e "\e[34mRequests made to KNOXSS API: $TARGET_COUNT\e[0m"
echo -e "\e[32m🤘 XSS scan completed! 🤘\e[0m"

echo "Scan completed! Check '$OUTPUT_FILE' for full results."
