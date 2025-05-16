#!/bin/bash

# Script to fix UID/GID-based ownership issues in Proxmox LXC containers (with dry-run and confirmation)
# Script was created with the help of ChatGPT
# Prompt for input
read -p "Enter the numeric User ID (The old UID) to search for: " UID
read -p "Enter the numeric Group ID (The old GID) to search for: " GID
read -p "Enter the new username to assign ownership to: " USERNAME
read -p "Enter the new group name to assign ownership to: " GROUPNAME
read -p "Enter the LXC container number (CTID): " CTID

# Validate UID/GID/CTID
if ! [[ "$UID" =~ ^[0-9]+$ ]]; then
  echo "Error: UID must be a number."
  exit 1
fi

if ! [[ "$GID" =~ ^[0-9]+$ ]]; then
  echo "Error: GID must be a number."
  exit 1
fi

if ! [[ "$CTID" =~ ^[0-9]+$ ]]; then
  echo "Error: CTID must be a number."
  exit 1
fi

# Validate username and group
if ! id "$USERNAME" &>/dev/null; then
  echo "Error: User '$USERNAME' does not exist on the host."
  exit 1
fi

if ! getent group "$GROUPNAME" &>/dev/null; then
  echo "Error: Group '$GROUPNAME' does not exist on the host."
  exit 1
fi

# Check if container is running
STATUS=$(pct status "$CTID" | awk '{print $2}')

if [ "$STATUS" = "running" ]; then
  echo "Container $CTID is running. Stopping it..."
  pct stop "$CTID" || { echo "Failed to stop container $CTID."; exit 1; }
else
  echo "Container $CTID is already stopped."
fi


# Mount the container
echo "Mounting container $CTID..."
MOUNT_OUTPUT=$(pct mount "$CTID") || { echo "Failed to mount container $CTID."; exit 1; }

# Extract path to rootfs
MOUNT_PATH=$(echo "$MOUNT_OUTPUT" | sed -n "s/.*'\(.*\)'.*/\1/p")

# Check the path exists
if [ ! -d "$MOUNT_PATH" ]; then
  echo "Error: Extracted mount path '$MOUNT_PATH' does not exist."
  exit 1
fi

echo "Container rootfs mounted at: $MOUNT_PATH"


echo ""
echo "🔍 Performing dry run (no changes made yet)..."
echo ""

# Dry run – show what would be done
find "$MOUNT_PATH" -user "$UID" -type f -exec echo chown "$USERNAME:$GROUPNAME" {} +
find "$MOUNT_PATH" -user "$UID" -type d -exec echo chown "$USERNAME:$GROUPNAME" {} +
find "$MOUNT_PATH" -user "$UID" -type l -exec echo chown -h "$USERNAME:$GROUPNAME" {} +

find "$MOUNT_PATH" -group "$GID" -type f -exec echo chown ":$GROUPNAME" {} +
find "$MOUNT_PATH" -group "$GID" -type d -exec echo chown ":$GROUPNAME" {} +
find "$MOUNT_PATH" -group "$GID" -type l -exec echo chown -h ":$GROUPNAME" {} +

echo ""
read -p "✅ Proceed with making these changes? [Y/N]: " CONFIRM
case "$CONFIRM" in
  [Yy]* )
    echo "🔧 Applying ownership changes..."

    # Files/directories/symlinks owned by UID
    find "$MOUNT_PATH" -user "$UID" -type f -exec chown "$USERNAME:$GROUPNAME" {} +
    find "$MOUNT_PATH" -user "$UID" -type d -exec chown "$USERNAME:$GROUPNAME" {} +
    find "$MOUNT_PATH" -user "$UID" -type l -exec chown -h "$USERNAME:$GROUPNAME" {} +

    # Files/directories/symlinks owned by GID
    find "$MOUNT_PATH" -group "$GID" -type f -exec chown ":$GROUPNAME" {} +
    find "$MOUNT_PATH" -group "$GID" -type d -exec chown ":$GROUPNAME" {} +
    find "$MOUNT_PATH" -group "$GID" -type l -exec chown -h ":$GROUPNAME" {} +

    echo "✅ Ownership update completed."
    ;;
  [Nn]* )
    echo "❌ No changes made. Exiting..."
    pct unmount "$CTID"
    exit 0
    ;;
  * )
    echo "Invalid input. Exiting."
    pct unmount "$CTID"
    exit 1
    ;;
esac

# Unmount and restart the container
echo "Unmounting container $CTID..."
pct unmount "$CTID"

echo "Starting container $CTID..."
pct start "$CTID"

echo "✅ All done."
