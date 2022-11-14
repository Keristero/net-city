# Net City Server

## Homepages
When a user connects to the server, they will have their own home page instance generated (based on base_homepage.tmx) and saved to their player_memory
After some home pages have been generated, be careful not to change base_homepage.tmx in a way which would modify existing tile GIDs, the saved player homepages may break.

### bugs
if the server crashes while a player is removing decorations from their homepage they will end up with duplicates.

### ubuntu setup
clone the repo
`git clone --recurse-submodules --remote-submodules https://github.com/Keristero/net-city.git`

install rust + cargo (if you dont already have it)
`curl https://sh.rustup.rs -sSf | sh`
restart your terminal after install

get build essentials
`sudo apt install build-essential`

get libssl
`sudo apt install libssl-dev`

get pkg-config
`sudo apt-get install pkg-config`

now compile and run the server
`cd gravy-yum`
`./update-and-run.sh`