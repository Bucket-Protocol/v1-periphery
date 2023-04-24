module bucket_periphery::well {

    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use bucket_protocol::bkt::BKT;
    use bucket_protocol::well::WellToken;
    use bucket_protocol::buck::{Self, BucketProtocol};

    public entry fun stake<T>(
        protocol: &mut BucketProtocol,
        bkt_coin: Coin<BKT>,
        ctx: &mut TxContext,  
    ) {
        let bkt_input = coin::into_balance(bkt_coin);
        let well_token = buck::stake<T>(protocol, bkt_input, ctx);
        transfer::public_transfer(well_token, tx_context::sender(ctx));
    }

    public entry fun unstake<T>(
        protocol: &mut BucketProtocol,
        well_token: WellToken<T>,
        ctx: &mut TxContext,  
    ) {
        let (bkt, reward) = buck::unstake<T>(protocol, well_token);
        let user = tx_context::sender(ctx);
        transfer::public_transfer(coin::from_balance(bkt, ctx), user);
        transfer::public_transfer(coin::from_balance(reward, ctx), user);
    }


    public entry fun claim<T>(
        protocol: &mut BucketProtocol,
        well_token: &mut WellToken<T>,
        ctx: &mut TxContext,  
    ) {
        let reward = buck::claim<T>(protocol, well_token);
        transfer::public_transfer(coin::from_balance(reward, ctx), tx_context::sender(ctx));
    }


}