# proxmox-lxc-permissions-fix
Script to fix container permissions when changing uid/gid mapping on the host.


This is a script I designed (With the help of ChatGPT) to help with permissions fixes on lxc containers when you change thier host mapping. 
The initial issue was when changing root mapping the container no longer was able to access its own files as root. 
I found a fix online but decided I wanted to automate it with a script which i've put here for you all to use. 
I have tested it myself and it works for my use case, when run it will ask for some input, original userid, group id, then new user id and new group id,
Lastly itll ask for the LXC number (Listed in Proxmox) Itll then stop the container (If its running) Then mount the file system and do a dry run,
at that point itll ask if you wish to continue, yes and itll change all the permissions for you, unmount the filesystem then start the LXC, No will return you to the prompt.

Im no professional coder, Homnelab and gaming is just a hobby of mine, but i wouldnt be anywhere now if it wasnt for the great help i've found on the internet, 
this is my way of giving back!
