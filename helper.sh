export $(grep -v '^#' common.env | xargs)
export DATE=$(date +%Y%m%d-%H%M%S)

shopt -s expand_aliases
source alias.sh

set -x

restore() {
    git clean -xdf
    git checkout .
}

genBootNodes() {
    enodes=""
    for id in $(seq -f '%g' 1 $NODE_NUM); do
        # devp2p key to-enode --help
        # return
        # tmp=$(devp2p key to-enode l1-tmp-data/node$id/execution/geth/nodekey | sed "s/127.0.0.1/el$id/g")
        tmp=$(devp2p key to-enode conf/execution/nodekey/node$id | sed "s/127.0.0.1/el$id/g")
        enodes="$enodes;$tmp"
    done
    sed -i '/GETH_BOOTNODES/d' el.env
    echo "GETH_BOOTNODES=$enodes" >>el.env
    sed -i 's/GETH_BOOTNODES=;/GETH_BOOTNODES=/g' el.env
    return
}

restartL2() {
    downL2
    sleep 10s
    upL2
    return
}

downL2() {
    for id in sequencer replia1 replia2; do
        dcl2 --profile $id down -v
    done

    return
}

upL2() {
    for id in sequencer replia1 replia2; do
        dcl2 --profile $id up -d
    done
    return
}


restartL1Dev() {
    dcl1 down -v
    dcl1 up -d
    return
}

resetL1() {
    set -e
    dcl1 down -v
    rm -rf ./l1-tmp-data
    init
    dcl1 up -d
}

init() {
    initCL
    initEL
    return
}

initCL() {
    rm -rf ./conf/consensus/genesis.ssz*
    dockerRun \
        -v $(pwd):/host \
        --workdir /host \
        gcr.io/prysmaticlabs/prysm/cmd/prysmctl:latest testnet generate-genesis \
        --chain-config-file=./conf/consensus/config.yml \
        --deposit-json-file=./deposit.json \
        --config-name=l1 \
        --num-validators=64 \
        --genesis-time=0x0 \
        --genesis-time-delay=20 \
        --geth-genesis-json-in=./conf/execution/genesis.json \
        --geth-genesis-json-out=./conf/execution/genesis.json \
        --output-ssz=./conf/consensus/genesis.ssz \
        --output-json=./conf/consensus/genesis.ssz.json \
        --fork=deneb
    return
}

initEL() {
    for item in $(seq -f 'node%g' 1 $NODE_NUM); do
        dockerRun \
            -v $(pwd):/host \
            --workdir /host \
            ethereum/client-go:latest \
            --datadir=./l1-tmp-data/$item/execution \
            init \
            ./conf/execution/genesis.json
        mkdir -p l1-tmp-data/$item/consensus/beacon
    done
    return
}

newL2Node() {
    for item in $(seq -f 'node%g' 3 3); do
        echo $item
        # op-geth init \
        #     --datadir=l2-tmp-data/$item \
        #     conf/op/genesis.json
    done

}

newL1Node() {
    for item in $(seq -f 'node%g' 6 6); do
        dcl1 --profile $item down -v

        rm -rf l1-tmp-data/$item
        geth --datadir=./l1-tmp-data/$item/execution \
            init \
            ./conf/execution/genesis.json
        mkdir -p l1-tmp-data/$item/consensus/beacon
        sleep 10
        dcl1 --profile $item up -d
    done
}

runInContainer() {
    enodes=""
    for item in $(seq --format 'el%g' 1 4); do
        # dc logs --since 10m --no-log-prefix $item >$DIR/$item
        # echo $item
        # enode=$(dcl1 exec -t $item geth attach --exec "admin.nodeInfo")
        tmp=$(dcl1 exec -t $item geth attach --exec "admin.nodeInfo.enode" | tr -d '"')
        enode=$(sed "s|127.0.0.1|$item|g" <<<$tmp)
        enodes="$enodes,$enode"
    done
    echo $enodes
}
probeNetwork() {
    for item in $(dcl1 ps --services --all); do
        name=$COMPOSE_PROJECT_NAME-$item-1
        docker container inspect $name | jq '.[0].NetworkSettings.Networks' >tmp-container-$item.json
    done
    sha1sum tmp-container*.json
    wc tmp-container*.json
    return
}

logL1() {
    # exec >"$FUNCNAME.log" 2>&1
    DIR=log-l1dev-stopallel-$DATE-$1
    mkdir $DIR

    for item in $(dcl1 ps --services --all); do
        dcl1 logs \
            --no-log-prefix \
            --since 20m \
            $item >$DIR/$item
    done
}

logL2() {
    DIR=log-$DATE-$1
    mkdir $DIR
    for item in $(dcl2 ps --services --all); do
        dcl2 logs \
            -no-log-prefix \
            $item >$DIR/$item
    done
    return
}

probeValidator() {
    curl http://localhost:7000/eth/v1/keystores
}

probeLog() {
    files=$(ls *)
    # sha1sum $files
    # wc $files
    # du $files
    grep -irnc err $files
    return
}

debug() {
    docker run \
        --rm \
        -it \
        -v $(pwd):/host \
        --workdir /host \
        ethereum/client-go:latest
    # gcr.io/prysmaticlabs/prysm/cmd/prysmctl:latest --version
    # gcr.io/prysmaticlabs/prysm/validator:latest --version
    # gcr.io/prysmaticlabs/prysm/beacon-chain:latest
    # alpine
    # --entrypoint sh \
    # --name b2debug \

    return
}

queryIdentity() {
    rm tmp.log
    for id in $(seq 1 $NODE_NUM); do
        # curl http://cl$id:3500/eth/v1/node/identity | jq '.'
        # return
        curl http://cl$id:3500/eth/v1/node/identity | jq '.data.p2p_addresses[1]' | tr -d '"' >>tmp.log
        # curl http://cl$id:3500/eth/v1/node/health
    done
    cat tmp.log
    return
}

probeCL() {
    for id in $(seq 1 $NODE_NUM); do
        # curl http://cl$id:3500/eth/v1/node/health
        # curl http://cl$id:3500/eth/v1/node/peer_count
        curl http://cl$id:3500/eth/v1/node/peers | jq .
    done
    # curl $BEACON_REST/node/identity
    # curl $BEACON_REST/node/syncing
    # curl $BEACON_RESTalpha1/node/eth1/connections | jq .
    # curl $BEACON_REST/beacon/genesis
    return
    # curl $BEACON_REST/beacon/headers | jq .
    # curl $BEACON_REST/beacon/headers/5 | jq .
    # curl $BEACON_REST/beacon/blocks/5 | jq .

    # 404
    # curl $BEACON_REST/beacon/deposit_snapshot
    # curl $BEACON_REST/beacon/light_client/updates

    for id in genesis finalized justified head; do
        curl $BEACON_REST/beacon/states/$id/root | jq .
        # curl $BEACON_REST/beacon/states/$id/fork | jq .
        # curl $BEACON_REST/beacon/states/$id/validators | jq . >tmp-$id.json
        # curl $BEACON_REST/beacon/states/$id/finality_checkpoints | jq .
        # curl $BEACON_REST/beacon/states/$id/validator_balances| jq .
        # curl $BEACON_REST/beacon/states/$id/committees | jq .
        # curl $BEACON_REST/beacon/states/$id/sync_committees | jq .
        # curl $BEACON_REST/beacon/states/$id/randao | jq .
    done

    # config
    # curl $BEACON_REST/config/spec | jq .
    # curl $BEACON_REST/config/fork_schedule | jq .
    # curl $BEACON_REST/config/deposit_contract | jq .

    # debug
    # curl $BEACON_REST/debug/beacon/states/finalized| jq .
    # curl $BEACON_REST/debug/beacon/heads | jq .
    # curl $BEACON_REST/debug/fork_choice | jq .

    # events
    # curl $BEACON_REST/events | jq .

    # node
    # curl $BEACON_REST/node/identity | jq .
    # curl $BEACON_REST/node/peers | jq .
    # curl $BEACON_REST/node/peer_count | jq .
    # curl $BEACON_REST/node/version | jq .
    # curl $BEACON_REST/node/syncing | jq .
    # curl $BEACON_REST/node/health

    # validator
    # curl $BEACON_REST/validator/attestation_data | jq .
    # curl $BEACON_REST/validator/aggregate_attestation| jq .

    # validator required api
    # curl $BEACON_REST/beacon/genesis | jq .

    # rewards
    # curl $BEACON_REST/beacon/rewards/blocks/1 | jq .
    # curl $BEACON_REST/beacon/rewards/blocks/100 | jq .

    # l1 exec -it validator /app/cmd/validator/validator \
    #     --l1-tmp-data=/consensus/validatordata \
    #     --accept-terms-of-use \
    #     --chain-config-file=/consensus/config.yml \
    #     accounts --help

    # wallet --help
    # curl http://localhost:8080/healthz
    return
}

download() {
    # wget https://github.com/prysmaticlabs/prysm/releases/download/v4.1.1/beacon-chain
    # wget https://github.com/prysmaticlabs/prysm/releases/download/v4.1.1/beacon-chain-v4.1.1-modern-linux-amd64
    # wget https://github.com/prysmaticlabs/prysm/releases/download/v4.1.1/client-stats
    # wget https://github.com/prysmaticlabs/prysm/releases/download/v4.1.1/prysmctl
    # wget https://github.com/prysmaticlabs/prysm/releases/download/v4.1.1/validator
    return
}

cpNodeKey() {
    for name in $(seq -f 'node%g' 1 $NODE_NUM); do
        cp l1-tmp-data/$name/execution/geth/nodekey conf/gethnodekey/$name
    done
    sha1sum conf/gethnodekey/*
}

probeOPNodes() {
    PREFIX=tmp-
    rm -rf $PREFIX*
    for item in node1 node2; do
        curlPost http://$item:9545 --data '{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}' | jq . >tmp-$item.json
        # curlPost http://$item:9545 --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' | jq . > tmp-$item.json
        # curlPost http://$item:9545 --data '{"jsonrpc":"2.0","method":"optimism_rollupConfig","params":[],"id":1}' | jq . > tmp-$item.json
        # curlPost http://$item:9545 --data '{"jsonrpc":"2.0","method":"optimism_version","params":[],"id":1}' | jq . > tmp-$item.json
    done
    sha1sum $PREFIX*
    wc $PREFIX*
}

probeOPNode() {
    # curlPostOPNode '{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}'  | jq .
    # curlPostOPNode '{"jsonrpc":"2.0","method":"opp2p_peers","params":[true],"id":1}'  | jq .
    # curlPostOPNode '{"jsonrpc":"2.0","method":"opp2p_peerStats","params":[],"id":1}'  | jq .
    # curlPostOPNode '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}'  | jq .
    # curlPostOPNode '{"jsonrpc":"2.0","method":"optimism_rollupConfig","params":[],"id":1}' | jq .
    # curlPostOPNode '{"jsonrpc":"2.0","method":"opp2p_listBlockedPeers","params":[],"id":1}' | jq .
    curlPostOPNode '{"jsonrpc":"2.0","method":"optimism_version","params":[],"id":1}' | jq .
    return
}

probePeerForkDigest() {
    # grep -m 3 -irnE 'fork digest of peer with ENR.*\:' tmp.enr
    # grep -m 3 -irnE 'fork digest of peer with ENR.*:' tmp.enr
    # grep -m 3 -irn 'fork digest of peer with ENR.*(\:)?' tmp.enr
    rm -f tmp.enr.list
    for item in $(cat tmp.enr); do
        echo $item >tmp.log
        devp2p enrdump --file tmp.log >>tmp.enr.list
        # return
    done

    grep -ir ip tmp.enr.list | sort -u | grep 172
    return
}

probeDevContainer() {
    TMP_FILE=tmp-container.log
    rm -f $TMP_FILE
    for item in $(dcl1 ps --services --all); do
        dcl1 exec -it $item ip a
        # dcl1 exec -it $item uname -a >> $TMP_FILE
        # dcl1 exec -it $item date >> $TMP_FILE
        # dcl1 exec -it $item date --rfc-3339=seconds
        # echo $item
    done
    wc $TMP_FILE
    return
}
tmp() {
    beacon-chain \
        --config-file=/app-conf/beacon-chain.yml \
        --execution-endpoint=http://el4:8551 \
        --checkpoint-sync-url=http://cl3:3500 \
        --peer=/dns4/cl1/tcp/13000/p2p/16Uiu2HAmLeoUgNt8cQ5E1ajHgR8smKnWeVoZY4Edqu6tN9Zj8Q1h \
        --peer=/dns4/cl2/tcp/13000/p2p/16Uiu2HAm5nsnnE6SGQAQgM4EtjephsJa6QpnKnYJACZ9YVY6p3dk \
        --peer=/dns4/cl3/tcp/13000/p2p/16Uiu2HAm7JJDLMPM7ree9iG3oWEHTWGAS86XTax95qZ4HR5aGzQZ \
        --p2p-host-dns=cl4 \
        --genesis-beacon-api-url=http://cl3:3500 \
        --verbosity=info
    # --verbosity=debug
    # --clear-db \
    # --suggested-fee-recipient=0xc42990bdb206D1675284D98081607EcEEbb3F108 \
    # --peer=/ip4/172.19.0.11/tcp/13000/p2p/16Uiu2HAm7JJDLMPM7ree9iG3oWEHTWGAS86XTax95qZ4HR5aGzQZ \
    return
}

probeDC() {
    # yq '.services[].image' l1.yml
    # yq '.services[].profiles[0]' l1.yml
    # yq '.services | keys' l1.yml
    return
}

monitor() {
    dc --file monitor.yml down
    dc --file monitor.yml up -d
}

help() {
    # exec >"$FUNCNAME.log" 2>&1
    # for item in geth beacon-chain prysmctl validator; do
    #     $item --help >$item.help
    # done
    prysmctl testnet generate-genesis --help >prysmctl-testnet-generate-genesis.help
    # geth attach --help >geth-attach.help
    return
}

createWallet() {
    # validator --help
    # validator wallet --help
    validator wallet create --help
    validator accounts import --help

    KEY_PREFIX=./conf/consensus/validators
    WALLET_PREFIX=./conf/consensus/wallet
    for id in $(seq 1 $NODE_NUM); do
        # for id in $(seq 6 6); do
        wallet_path=$WALLET_PREFIX$id
        key_path=$KEY_PREFIX$id
        rm -rf $wallet_path
        mkdir $wallet_path

        # wallet_path=conf/consensus/all-wallets
        # key_path=conf/consensus/all-validators
        # # password 74e3d396-3a80-11ef-982c-d37331a7b6f8

        validator wallet create \
            --wallet-dir $wallet_path \
            --accept-terms-of-use \
            --wallet-password-file conf/consensus/wallet.pw

        validator accounts import \
            --wallet-dir $wallet_path \
            --keys-dir $key_path \
            --wallet-password-file=conf/consensus/wallet.pw

        # validator accounts --help
        # validator accounts list --help
        validator accounts list \
            --wallet-dir $wallet_path \
            --wallet-password-file=conf/consensus/wallet.pw
    done
    # ccl http://cl1:3500/eth/v1/beacon/states/head/validators/0xa6c5e4dba7fbd46fc331efce261642b5cd9f3a4bce0f62ad51d979b637653c495d6dc66b22f1a62ad3b187a5f94c2714
    # ccl http://cl1:3500/eth/v1/beacon/states/head/validators/0xb053234cbcab38a92a0f06c0c46e694de07cb05045452ed0011cb5bc760dc18ed97521e209329e569365ab9976ddef55

    return
}

addValidator() {
    validator \
        --beacon-rpc-provider=cl1:4000 \
        --chain-config-file=/app-conf/config.yml \
        --suggested-fee-recipient=0x0eDcC19BaCA33F7DEC3C51FF0eF5b414b923e9CB \
        --verbosity trace \
        --wallet-password-file=conf/consensus/wallet.pw
    # --wallet-dir=./vali-wallet \
    # --enable-builder \
    #   --interop-num-validators=64 \
    #   --interop-start-index=0 \
    return
}

newNodeKey() {
    for item in $(seq -f 'node%g' 1 $NODE_NUM); do
        # openssl rand -hex 32 >conf/execution/nodekey/$item
        openssl rand -hex 32 >conf/op/$item.jwt
        # echo $item
    done
}

partialWithdrawal() {
    # ccl http://cl1:3500/eth/v1/beacon/states/head/validators/1729
    # prysmctl validator --help
    # prysmctl validator withdraw --help
    # return

    # generate
    # python3 ./staking_deposit/deposit.py generate-bls-to-execution-change
    # send to beacon-node
    prysmctl validator withdraw \
        --beacon-node-host=cl1:3500 \
        --path bls_to_execution_changes \
        --accept-terms-of-use \
        --confirm
}

fullWithdrawal() {
    # exit validator
    # prysmctl validator --help
    # prysmctl validator voluntary-exit --help > pvv.help
    # validator accounts list --wallet-password-file=conf/consensus/wallet.pw
    # ccl http://cl1:3500/eth/v1/beacon/states/head/validators/1729
    # ccl http://cl1:3500/eth/v1/beacon/headers
    # ccl http://cl1:3500/eth/v1/config/spec
    # ccl http://cl1:3500/eth/v1/node/syncing
    # ccl http://cl1:3500/eth/v1/validator/sync_committee_contribution
    # ccl http://cl1:3500/eth/v1/events?topics=block
    # return
    prysmctl validator voluntary-exit \
        --accept-terms-of-use \
        --beacon-rpc-provider cl1:4000 \
        --wallet-dir /root/.eth2validators/prysm-wallet-v2/ \
        --wallet-password-file conf/consensus/wallet.pw \
        --grpc-max-msg-size 21474836470 \
        --public-keys 0xa6c5e4dba7fbd46fc331efce261642b5cd9f3a4bce0f62ad51d979b637653c495d6dc66b22f1a62ad3b187a5f94c2714
}

clMultiClient() {
    rm -rf tmp*
    for endpoint in $CL_ENDPOINTS; do
        name=${endpoint%:*}
        name=tmp-${name#*//}.json
        # ccl $endpoint/eth/v1/node/identity | jq '.data.p2p_addresses[0]' | tr -d '"'
        # ccl $endpoint/eth/v1/node/identity
        # ccl $endpoint/eth/v1/beacon/genesis | jq .data
        # ccl $endpoint/eth/v1/node/version > $name
        # ccl $endpoint/eth/v1/node/syncing > $name
        ccl $endpoint/eth/v1/beacon/headers >$name
        # ccl $endpoint/eth/v1/node/peers | jq '.data[].peer_id' tmp-101.33.45.234.json | sort -u > $name
        # return
    done
    sha1sum tmp*
    # wc tmp*
    # head tmp*
}

elMultiClient() {
    rm -rf tmp*
    for endpoint in $EL_ENDPOINTS; do
        name=${endpoint%:*}
        name=tmp-${name#*//}.json
        # curl -s --url $endpoint --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq .
        # curl -s --url $endpoint --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x1ac4",true],"id":1}' > $name
        curl -s --url $endpoint --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x198b",true],"id":1}' >$name
        # return
    done
    sha1sum tmp*
}

readDB() {
    # psql "select count(*) from blocks"
    # psql "select * from transactions limit 10;"
    # psql "select hash from transactions;" > txhashs.csv
    # psql "select hash from blocks;" > blockhashs.csv

    # psql "\dt"
    # psql "select count(*) from logs;"
    # psql "select * from logs limit 10;" > tmp.log
    return
}

convertToK8S() {
    rm -f tmp.yml
    export $(grep -v '^#' b2hub.env | xargs)
    kompose convert \
        --file devcontainer.yml \
        --out tmp.yml \
        --secrets-as-files \
        --with-kompose-annotation=false \
        --verbose
    # --controller deployment \
    return
}

collectL1Info() {
    rm tmp.log
    for addr in $(cat oldL1Addr.csv); do
        # geth snapshot inspect-account --help
        # echo $addr >> tmp.log
        geth snapshot inspect-account $addr | tail -n 4 >>tmp.log
        # return
    done
    return
}

probeNetworkCantRecoverAfterStopAllEL1M() {
    for id in $(seq 1 $NODE_NUM); do
        dcl1 down el$id -v
    done

    sleep 10m

    for id in $(seq 1 $NODE_NUM); do
        dcl1 up -d el$id
    done
    return
}

$@
