module bucket_periphery::tank_operations {

    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_protocol::tank::{Self, ContributorToken};
    use bucket_periphery::utils;

    public entry fun deposit<T>(
        protocol: &mut BucketProtocol,
        buck_coin: Coin<BUCK>,
        ctx: &mut TxContext,
    ) {
        let tank = buck::borrow_tank_mut<T>(protocol);
        let buck_input = coin::into_balance(buck_coin);
        let tank_token = tank::deposit(tank, buck_input, ctx);
        transfer::public_transfer(tank_token, tx_context::sender(ctx));
    }

    public entry fun withdraw<T>(
        protocol: &mut BucketProtocol,
        clock: &Clock,
        token: ContributorToken<BUCK, T>,
        lock_time: u64,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let st_bkt = buck::claim_st_bkt<T, T>(protocol, clock, &mut token, lock_time, ctx);
        transfer::public_transfer(st_bkt, user);
        let tank = buck::borrow_tank_mut<T>(protocol);
        let (buck_output, collateral) = tank::withdraw(tank, token);
        utils::transfer_non_zero_balance(buck_output, user, ctx);
        utils::transfer_non_zero_balance(collateral, user, ctx);
    }

    public entry fun claim<T>(
        protocol: &mut BucketProtocol,
        clock: &Clock,
        token: &mut ContributorToken<BUCK, T>,
        lock_time: u64,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let st_bkt = buck::claim_st_bkt<T, T>(protocol, clock, token, lock_time, ctx);
        transfer::public_transfer(st_bkt, user);
        let tank = buck::borrow_tank_mut<T>(protocol);
        let collateral = tank::claim_collateral(tank, token);
        utils::transfer_non_zero_balance(collateral, user, ctx);
    }
}