# DirtyKnoxss - Automated XSS Scanner Using Knoxss API
Automation for knoxss
DirtyKnoxss is a Bash script that automates Knoxss API calls to detect XSS vulnerabilities across multiple URLs efficiently.

## Features
✅ Parallel Execution - Scan multiple URLs simultaneously for faster results

✅ Error Handling - Displays errors and saves unfinished URLs if interrupted

✅ XSS Filtering - Only stores URLs where XSS is detected

✅ API Usage Tracking - Shows remaining API calls and reset time

## Installation
### Prerequisites
Ensure you have the following installed:
```
sudo apt install jq parallel curl -y  # For Debian/Ubuntu
```
## Clone the Repository
```
git clone https://github.com/dirtycoder0124/dirtyknoxss.git
cd dirtyknoxss
chmod +x dirtyknoxss.sh
```
## Usage
### Run the Script
```
./dirtyknoxss.sh urls.txt
```
- urls.txt should contain one URL per line.

## Handling Interruptions
If the script is stopped manually (CTRL+C) or crashes, remaining URLs are saved in:
📌 knoxss_remaining.todo

## To resume scanning:
```
./dirtyknoxss.sh knoxss_remaining.todo
```
## Notes
- Replace API_KEY in the script with your Knoxss Pro API Key.

- Use responsibly and only on authorized targets.
