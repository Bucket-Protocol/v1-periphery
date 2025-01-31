module bucket_periphery::tank_operations {

    use std::vector as vec;
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::balance;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_protocol::bucket;
    use bucket_protocol::tank::{Self, ContributorToken};
    use bucket_protocol::bkt::{BKT, BktTreasury};
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
        bkt_treasury: &mut BktTreasury,
        mut tokens: vector<ContributorToken<BUCK, T>>,
        withdrawal_amount: u64,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let mut buck_output = balance::zero<BUCK>();
        let mut collateral_output = balance::zero<T>();
        let mut bkt_output = balance::zero<BKT>();
        let mut token_len = vec::length(&tokens);
        while (token_len > 0) {
            let token = vec::pop_back(&mut tokens);
            let (buck_remain, collateral_reward, bkt_reward) = buck::tank_withdraw<T>(protocol, oracle, clock, bkt_treasury, token, ctx);
            balance::join(&mut buck_output, buck_remain);
            balance::join(&mut collateral_output, collateral_reward);
            balance::join(&mut bkt_output, bkt_reward);
            token_len = token_len - 1;
        };
        vec::destroy_empty(tokens);
        let re_deposit_amount = balance::value(&buck_output) - withdrawal_amount;
        if (re_deposit_amount > 0) {
            let deposit_input = balance::split(&mut buck_output, re_deposit_amount);
            let tank = buck::borrow_tank_mut<T>(protocol);
            let token = tank::deposit(tank, deposit_input, ctx);
            transfer::public_transfer(token, user);
        };
        utils::transfer_non_zero_balance(buck_output, user, ctx);
        utils::transfer_non_zero_balance(collateral_output, user, ctx);
        utils::transfer_non_zero_balance(bkt_output, user, ctx);
    }

    public entry fun claim<T>(
        protocol: &mut BucketProtocol,
        bkt_treasury: &mut BktTreasury,
        token: &mut ContributorToken<BUCK, T>,
        ctx: &mut TxContext,
    ) {
        let user = tx_context::sender(ctx);
        let tank = buck::borrow_tank_mut<T>(protocol);
        let (collateral_reward, bkt_reward) = tank::claim(tank, bkt_treasury, token, ctx);
        utils::transfer_non_zero_balance(collateral_reward, user, ctx);
        utils::transfer_non_zero_balance(bkt_reward, user, ctx);
    }

    public fun liquidate_with_self_buck<T>(
        protocol: &mut BucketProtocol,
        oracle: &mut BucketOracle,
        bkt_treasury: &mut BktTreasury,
        clock: &Clock,
        buck_coin: &mut Coin<BUCK>,
        page_size: u64,
        ctx: &mut TxContext,
    ) {
        let (needed_amount, mut debtors) = get_amount_needed_to_liquidate<T>(
            protocol, oracle, clock, page_size,
        );
        let bucket = buck::borrow_bucket<T>(protocol);
        let is_in_recovery_mode = bucket::is_in_recovery_mode(bucket, oracle, clock);
        let tank = buck::borrow_tank_mut<T>(protocol);
        let buck_mut = coin::balance_mut(buck_coin);
        if (needed_amount == 0) return;
        let buck_in = balance::split(buck_mut, needed_amount);
        let token = tank::deposit(tank, buck_in, ctx);
        let mut total_rebate = balance::zero<T>();
        while (!vec::is_empty(&debtors)) {
            let debtor = vec::pop_back(&mut debtors);
            let rebate = if (is_in_recovery_mode) {
                buck::liquidate_under_recovery_mode<T>(protocol, oracle, clock, debtor)
            } else {
                buck::liquidate_under_normal_mode<T>(protocol, oracle, clock, debtor)
            };
            balance::join(&mut total_rebate, rebate);
        };
        let (buck_out, mut coll_out, bkt_out) = buck::tank_withdraw<T>(
            protocol,
            oracle,
            clock,
            bkt_treasury,
            token,
            ctx,
        );
        balance::join(&mut coll_out, total_rebate);
        let tx_sender = tx_context::sender(ctx);
        balance::join(buck_mut, buck_out);
        utils::transfer_non_zero_balance(coll_out, tx_sender, ctx);
        utils::transfer_non_zero_balance(bkt_out, tx_sender, ctx);
    }

    public fun get_reserve_in_tank<T>(
        protocol: &BucketProtocol
    ): u64 {
        let tank = buck::borrow_tank<T>(protocol);
        tank::get_reserve_balance(tank)
    }

    public fun get_amount_needed_to_liquidate<T>(
        protocol: &BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        page_size: u64,
    ): (u64, vector<address>) {
        let bucket = buck::borrow_bucket<T>(protocol);
        let mut cursor = bucket::get_lowest_cr_debtor(bucket);
        let mut unhealthy_debtors = vector<address>[];
        let mut counter = 0;
        let mut needed_amount = 0;
        while (option::is_some(&cursor) && counter < page_size) {
            let debtor = *option::borrow(&cursor);
            if (bucket::is_healthy_bottle_by_debtor(
                bucket, oracle, clock, debtor,
            )) break;
            let (_, debt_amount) = bucket::get_bottle_info_with_interest_by_debtor(
                bucket, debtor, clock,
            );
            vec::push_back(&mut unhealthy_debtors, debtor);
            needed_amount = needed_amount + debt_amount;
            counter = counter + 1;
            cursor = *bucket::next_debtor(bucket, debtor);
        };
        vec::reverse(&mut unhealthy_debtors);
        (needed_amount, unhealthy_debtors)
    }
}