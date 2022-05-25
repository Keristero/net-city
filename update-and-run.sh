cd Scriptable-OpenNetBattle-Server
git pull
cargo build --release
cp ./target/release/net_battle_server ../
cd ../
./net_battle_server