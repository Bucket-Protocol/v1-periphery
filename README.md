# Bucket Periphery
Entry functions for [frontend](https://bucketprotocol.io/)

## Testnet
Package ID
```
0x73ca5d35ac23c5175db576930b2088e49b3af5b7ae86a32dd047ecc762e7c606
```
Bucket Protocol ID,  version `241720` and ID
```
0x465547ecb5bf78f04fefe9ae1999de43bed5b01e3d5d095600fefbc956b8c599
```
Bucket Oracle ID,  version `37` and ID
```
0xff459a65463a4ed60f722b1e188092ca51dc51149c90827df37392fe09105eef
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
