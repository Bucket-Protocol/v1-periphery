module bucket_periphery::tank_operations {

    use std::vector;
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::balance;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_protocol::tank::{Self, ContributorToken};
    use bucket_protocol::bkt::BKT;
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
        tokens: vector<ContributorToken<BUCK, T>>,
        re_deposit_amount: u64,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let buck_output = balance::zero<BUCK>();
        let collateral_output = balance::zero<T>();
        let bkt_output = balance::zero<BKT>();
        let token_len = vector::length(&tokens);
        while (token_len > 0) {
            let token = vector::pop_back(&mut tokens);
            let (buck_remain, collateral_reward, bkt_reward) = buck::tank_withdraw<T>(protocol, oracle, clock, token);
            balance::join(&mut buck_output, buck_remain);
            balance::join(&mut collateral_output, collateral_reward);
            balance::join(&mut bkt_output, bkt_reward);
            token_len = token_len - 1;
        };
        vector::destroy_empty(tokens);
        let deposit_input = balance::split(&mut buck_output, re_deposit_amount);
        let tank = buck::borrow_tank_mut<T>(protocol);
        let token = tank::deposit(tank, deposit_input, ctx);
        transfer::public_transfer(token, user);
        utils::transfer_non_zero_balance(buck_output, user, ctx);
        utils::transfer_non_zero_balance(collateral_output, user, ctx);
        utils::transfer_non_zero_balance(bkt_output, user, ctx);
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