module bucket_periphery::well_operations {
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::clock::Clock;

    use bucket_protocol::bkt::BKT;
    use bucket_protocol::well::{Self, StakedBKT};
    use bucket_protocol::buck::{Self, BucketProtocol};
    use bucket_protocol::bkt::BktTreasury;
    use bucket_periphery::utils;

    public entry fun stake<T>(
        protocol: &mut BucketProtocol,
        clock: &Clock,
        bkt_coin: Coin<BKT>,
        lock_time: u64,
        ctx: &mut TxContext,
    ) {
        let bkt_input = coin::into_balance(bkt_coin);
        let well = buck::borrow_well_mut<T>(protocol);
        let st_bkt = well::stake<T>(clock, well, bkt_input, lock_time, ctx);
        transfer::public_transfer(st_bkt, tx_context::sender(ctx));
    }

    public entry fun unstake<T>(
        protocol: &mut BucketProtocol,
        clock: &Clock,
        st_bkt: StakedBKT<T>,
        ctx: &mut TxContext,
    ) {
        let well = buck::borrow_well_mut<T>(protocol);
        let (bkt, reward) = well::unstake<T>(clock, well, st_bkt);
        let user = tx_context::sender(ctx);
        utils::transfer_non_zero_balance(bkt, user, ctx);
        utils::transfer_non_zero_balance(reward, user, ctx);
    }

    public entry fun force_unstake<T>(
        protocol: &mut BucketProtocol,
        clock: &Clock,
        bkt_treasury: &mut BktTreasury,
        st_bkt: StakedBKT<T>,
        ctx: &mut TxContext,
    ) {
        let well = buck::borrow_well_mut<T>(protocol);
        let (bkt, reward) = well::force_unstake<T>(clock, well, bkt_treasury, st_bkt);
        let user = tx_context::sender(ctx);
        utils::transfer_non_zero_balance(bkt, user, ctx);
        utils::transfer_non_zero_balance(reward, user, ctx);
    }

    public entry fun claim<T>(
        protocol: &mut BucketProtocol,
        st_bkt: &mut StakedBKT<T>,
        ctx: &mut TxContext,
    ) {
        let well = buck::borrow_well_mut<T>(protocol);
        let reward = well::claim<T>(well, st_bkt);
        transfer::public_transfer(coin::from_balance(reward, ctx), tx_context::sender(ctx));
    }
}