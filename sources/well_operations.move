module bucket_periphery::well_operations {

    use std::ascii::{String};
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;

    use bucket_protocol::bkt::BKT;
    use bucket_protocol::well::{Self, StakedBKT};
    use bucket_protocol::buck::{Self, BucketProtocol};
    use bucket_protocol::bkt::{BktTreasury, BktAdminCap};
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

    public entry fun deposit_fee<T>(
        protocol: &mut BucketProtocol,
        coin: Coin<T>,
    ) {
        let well = buck::borrow_well_mut<T>(protocol);
        well::collect_fee(well, coin::into_balance(coin));
    }

    public fun deposit_fee_from<T>(
        protocol: &mut BucketProtocol,
        coin: Coin<T>,
        from: String,
    ) {
        let well = buck::borrow_well_mut<T>(protocol);
        well::collect_fee_from(well, coin::into_balance(coin), from);
    }

    public fun withdraw_reserve<T>(
        bkt_cap: &BktAdminCap,
        protocol: &mut BucketProtocol,
        ctx: &mut TxContext,
    ): Coin<T> {
        let well = buck::borrow_well_mut<T>(protocol);
        let withdrawal = well::withdraw_reserve(bkt_cap, well);
        coin::from_balance(withdrawal, ctx)
    }

    public fun withdraw_reserve_to<T>(
        bkt_cap: &BktAdminCap,
        protocol: &mut BucketProtocol,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let reserve = withdraw_reserve<T>(bkt_cap, protocol, ctx);
        if (coin::value(&reserve) > 0) {
            transfer::public_transfer(reserve, recipient);
        } else {
            coin::destroy_zero(reserve);
        };
    }
}