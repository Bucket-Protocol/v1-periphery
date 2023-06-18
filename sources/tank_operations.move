module bucket_periphery::tank_operations {

    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_protocol::tank::{Self, ContributorToken};
    use bucket_oracle::bucket_oracle::BucketOracle;
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
        oracle: &BucketOracle,
        clock: &Clock,
        token: ContributorToken<BUCK, T>,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let (buck_remain, collateral_reward, bkt_reward) = buck::tank_withdraw<T>(protocol, oracle, clock, token);
        utils::transfer_non_zero_balance(buck_remain, user, ctx);
        utils::transfer_non_zero_balance(collateral_reward, user, ctx);
        utils::transfer_non_zero_balance(bkt_reward, user, ctx);
    }

    public entry fun claim<T>(
        protocol: &mut BucketProtocol,
        token: &mut ContributorToken<BUCK, T>,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let tank = buck::borrow_tank_mut<T>(protocol);
        let (collateral_reward, bkt_reward) = tank::claim(tank, token);
        utils::transfer_non_zero_balance(collateral_reward, user, ctx);
        utils::transfer_non_zero_balance(bkt_reward, user, ctx);
    }
}