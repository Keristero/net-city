cd Scriptable-OpenNetBattle-Server
git pull
cargo build --release
copy .\target\release\net_battle_server.exe ..\net_battle_server.exe
cd ..\
net_battle_server.exe