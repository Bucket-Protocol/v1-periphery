# Bucket Periphery
Entry functions for [frontend](https://bucketprotocol.io/)

## Testnet
Package ID
```
0xee4692322f0ae27279f4fa8fe0391859320bebfb4be74ae3f22c051ffd5e3263
```
Bucket Protocol ID,  version `275`
```
0x8b7ff1f21c8e80683a4504f8e564ad42e51361875ecce8c9ecc5596a67abd225
```
Bucket Oracle ID,  version `274`
```
0xf6db6a423e8a2b7dea38f57c250a85235f286ffd9b242157eff7a4494dffc119
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
