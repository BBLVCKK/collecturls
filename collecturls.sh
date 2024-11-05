#!/bin/bash

# Input file containing URLs
input_file="httpx2XX.txt"

# Output files
katana_output="katana.txt"
wayback_output="wayback.txt"
gospider_output="gospider.txt"
archives_output="archives.txt"
final_output="allurls.txt"
error_log="error.log"

# Function to log errors
log_error() {
    echo "[ERROR] $1" >> "$error_log"
}

# Step 1: Use Katana to collect URLs
echo "Running Katana..."
katana -list "$input_file" -o "$katana_output" || log_error "Katana command failed on $input_file"

# Step 2: Use WaybackURLs to gather archived URLs
echo "Running WaybackURLs..."
if cat "$input_file" | waybackurls >> "$wayback_output"; then
    echo "WaybackURLs completed successfully."
else
    log_error "WaybackURLs command failed on $input_file"
fi

# Step 3: Use GoSpider to scrape URLs
echo "Running GoSpider..."
if gospider -S "$input_file" | sed -n 's/.*\(https:\/\/[^ ]*\)]*.*/\1/p' >> "$gospider_output"; then
    echo "GoSpider completed successfully."
else
    log_error "GoSpider command failed on $input_file"
fi

# Step 4: Custom Wayback Machine request for archived URLs
echo "Gathering URLs from Wayback Machine..."
while IFS= read -r url; do
    encoded_url=$(echo "$url" | sed 's/https:\/\///')  # Remove the "https://" prefix for the request
    if curl -s "https://web.archive.org/cdx/search/cdx?url=${encoded_url}*&output=text&fl=original&collapse=urlkey&from=" \
        -H "Sec-Ch-Ua: \"Not?A_Brand\";v=\"99\", \"Chromium\";v=\"130\"" \
        -H "Sec-Ch-Ua-Mobile: ?0" \
        -H "Sec-Ch-Ua-Platform: \"Windows\"" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -H "Upgrade-Insecure-Requests: 1" \
        -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 5_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B176 Safari/7534.48.3" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7" \
        -H "Sec-Fetch-Site: cross-site" \
        -H "Sec-Fetch-Mode: navigate" \
        -H "Sec-Fetch-User: ?1" \
        -H "Sec-Fetch-Dest: iframe" \
        -H "Referer: https://sawravchy.github.io/" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -H "Priority: u=0, i" \
        >> "$archives_output"; then
        echo "Archived URLs collected for $url."
    else
        log_error "Wayback Machine request failed for $url"
    fi
done < "$input_file"

# Step 5: Merge all URLs into final output
echo "Merging results into $final_output..."
if cat "$katana_output" "$wayback_output" "$gospider_output" "$archives_output" | anew >> "$final_output"; then
    echo "URLs merged successfully into $final_output."
else
    log_error "Failed to merge results into $final_output"
fi

# Output completion message
echo "All URLs collected and saved in $final_output. Errors, if any, logged in $error_log."
