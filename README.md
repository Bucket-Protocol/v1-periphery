# Bucket Periphery
Entry functions for [frontend](https://bucketprotocol.io/)

## Testnet
Package ID
```
0xfcc915136241c7ce7b1a5c95e3e8ad15080dd424836a19ce45e3c3ffb1736e96
```
Bucket Protocol version `57018` and ID
```
0x27357f4f4a0d5b8ea28c505ab560717578fa6b4044d4b226851ef5f04d1570f7
```
Bucket Oracle version `866734` and ID
```
0x5d552a9bd3162633c6990b8f8cbdc3a4280eec3687cdcb05984a977f0eccea90
```
SUI Tank version `57018` and ID
```
0x3b48e6a817e8d07d76e1c6884515ced5490d7468f2db4ac0b1c36a75dbf3ce67
```

## Localnet
Clone the repo and checkout to `localnet` branch
```
git clone https://github.com/Bucket-Protocol/v1-periphery.git
cd v1-periphery
git checkout localnet
```
Deploy all contracts including dependencies
```
sui client publish --with-unpublished-dependencies --gas-budget 50000000000
```
and find the package ID and object IDs of BucketProtocol and BucketOracle
