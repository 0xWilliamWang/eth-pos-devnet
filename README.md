This repository plans to use Geth+Prysm to build Ethereum private blockchain as L1, and [ethereum-optimism/optimism: Optimism is Ethereum, scaled.](https://github.com/ethereum-optimism/optimism) as L2 to learn and understand Ethereum Rollup.

This repository is forked from [OffchainLabs/eth-pos-devnet](https://github.com/OffchainLabs/eth-pos-devnet)

# TODO
- [x] Build l1 network
- [ ] Build l2 network
- [ ] Use a public mnemonic

# Usage
1. clone this repo
2. `bash helper.sh resetL1`, After successful startup, the following
    ```bash
    (base) B450M3600X eth-pos-devnet git:(master) ✗ dcl1 ps -a
    NAME        IMAGE                                            COMMAND                  SERVICE   CREATED          STATUS          PORTS
    l1-boot-1   ethereum/client-go:alltools-latest               "bootnode -nodekey=/…"   boot      14 seconds ago   Up 13 seconds   8545-8546/tcp, 30303/tcp, 30303/udp
    l1-cl1-1    gcr.io/prysmaticlabs/prysm/beacon-chain:latest   "/beacon-chain --con…"   cl1       14 seconds ago   Up 11 seconds   0.0.0.0:3500->3500/tcp, :::3500->3500/tcp
    l1-cl2-1    gcr.io/prysmaticlabs/prysm/beacon-chain:latest   "/beacon-chain --min…"   cl2       14 seconds ago   Up 11 seconds
    l1-cl3-1    gcr.io/prysmaticlabs/prysm/beacon-chain:latest   "/beacon-chain --min…"   cl3       14 seconds ago   Up 11 seconds
    l1-cl4-1    gcr.io/prysmaticlabs/prysm/beacon-chain:latest   "/beacon-chain --min…"   cl4       14 seconds ago   Up 12 seconds
    l1-cl5-1    gcr.io/prysmaticlabs/prysm/beacon-chain:latest   "/beacon-chain --con…"   cl5       14 seconds ago   Up 11 seconds
    l1-el1-1    ethereum/client-go:alltools-latest               "geth --identity=nod…"   el1       14 seconds ago   Up 12 seconds   8546/tcp, 0.0.0.0:8545->8545/tcp, :::8545->8545/tcp, 30303/tcp, 30303/udp
    l1-el2-1    ethereum/client-go:alltools-latest               "geth --identity=nod…"   el2       14 seconds ago   Up 12 seconds   8545-8546/tcp, 30303/tcp, 30303/udp
    l1-el3-1    ethereum/client-go:alltools-latest               "geth --identity=nod…"   el3       14 seconds ago   Up 12 seconds   8545-8546/tcp, 30303/tcp, 30303/udp
    l1-el4-1    ethereum/client-go:alltools-latest               "geth --identity=nod…"   el4       14 seconds ago   Up 12 seconds   8545-8546/tcp, 30303/tcp, 30303/udp
    l1-el5-1    ethereum/client-go:alltools-latest               "geth --identity=nod…"   el5       14 seconds ago   Up 12 seconds   8545-8546/tcp, 30303/tcp, 30303/udp
    l1-va1-1    gcr.io/prysmaticlabs/prysm/validator:latest      "/validator --config…"   va1       14 seconds ago   Up 11 seconds
    l1-va2-1    gcr.io/prysmaticlabs/prysm/validator:latest      "/validator --config…"   va2       14 seconds ago   Up 11 seconds
    l1-va3-1    gcr.io/prysmaticlabs/prysm/validator:latest      "/validator --config…"   va3       14 seconds ago   Up 11 seconds
    l1-va4-1    gcr.io/prysmaticlabs/prysm/validator:latest      "/validator --config…"   va4       14 seconds ago   Up 11 seconds
    l1-va5-1    gcr.io/prysmaticlabs/prysm/validator:latest      "/validator --config…"   va5       14 seconds ago   Up 11 seconds

    ```