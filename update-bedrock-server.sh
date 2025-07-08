#!/bin/bash

today=$(date +"%Y-%m-%d")

# Find if Minecraft Bedrock exist on the file system. If multiple installations exsist choose which one to update.
find_installations() {

    find / -type d -name "*.bak" -prune -o -type f -name "bedrock_server" -execdir test -e server.properties \; -printf "%h\n"

}

user_selection() {
    echo "Multiple Minecraft Bedrock server installations found:"
    PS3="Select an installation directory, if unsure Quit: "
    select installation_dir in "${installations_array[@]}" "Quit"; do
        if [ "$installation_dir" == "Quit" ]; then
            echo "Exiting..."
            exit 0
        elif [ -n "$installation_dir" ]; then
            break
        else
            echo "Invalid selection. Please choose a number from the list."
        fi
    done
}

installations=$(find_installations)

if [ -z "$installations" ]; then
    echo "No Minecraft Bedrock server installations found."
    exit 1
fi

readarray -t installations_array <<< "$installations"
if [ "${#installations_array[@]}" -eq 1 ]; then
    installation_dir="${installations_array[0]}"
    echo "Found one Minecraft Bedrock server installation at: $installation_dir"
else
    user_selection
fi

echo "Selected installation directory: $installation_dir"

while true; do
    read -p "To continue with update type 'u', to exit type 'x': " choice
    if [ "$choice" == "u" ]; then
        echo "Starting update..."
        # Place update code here
        break
    elif [ "$choice" == "x" ]; then
        echo "Exiting..."
        exit 0
    else
        echo "Invalid choice. Please choose 'U' to continue with update or 'X' to exit."
    fi
done

# Check the latest Minecraft Bedrock Edition Server available.
link=$(curl -s https://net-secondary.web.minecraft-services.net/api/v1.0/download/links | grep -oP '"downloadType":"serverBedrockLinux"[^}]*"downloadUrl":"\K[^"]+')

zip_file=$(basename "$link")

# Check the version of the installed Minecraft Bedrock Edition Server.

cd $installation_dir
output=$(sudo $installation_dir/bedrock_server 2>&1 &)

version=$(echo "$output" | grep -o 'Version: [0-9.]\+' | awk '{print $2}')

if [ -z "$version" ]; then
    echo "Failed to extract version from server output. Exiting."
    exit 1
fi

echo "Minecraft Bedrock server version is: $version"

if [[ $zip_file == *$version* ]]; then
echo "Minecraft Server is up to date, nothing to do!"
    exit 1
else
    echo "Downloading $link... "
    wget --header="Referer: https://www.minecraft.net/en-us/download/server/bedrock" --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36" -P /tmp "$link"
fi

sudo supervisorctl stop bedrock-server

# Make a backup of current Minecraft home directory.
read user group <<< $(stat -c '%U %G' "$installation_dir")

backup_dir="$installation_dir-$today.bak"

cp -a $installation_dir $backup_dir
echo "Backing up $installation_dir to $backup_dir..."

# Extract latest Minecraft Bedrock Edition Server & Remove Zip File.
unzip -o /tmp/$zip_file -d $installation_dir
rm /tmp/$zip_file

echo "Updating Minecraft... "
cp -a $backup_dir/server.properties $installation_dir
cp -a $backup_dir/allowlist.json $installation_dir
cp -a $backup_dir/permissions.json $installation_dir

chown -R $user:$group $installation_dir

# Start updated server
sudo supervisorctl reload
