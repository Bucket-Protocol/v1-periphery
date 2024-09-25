module bucket_periphery::bucket_operations {

    // Dependecies

    use std::option::{Self, Option};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Balance};
    use sui::clock::Clock;
    use sui::balance;

    use bucket_oracle::bucket_oracle::BucketOracle;
    use bucket_framework::linked_table;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_protocol::strap::{Self, BottleStrap};
    use bucket_protocol::bucket;
    use bucket_protocol::bottle;
    use bucket_periphery::utils;

    public fun borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        collateral_coin: Coin<T>,
        buck_output_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        let collateral_input = coin::into_balance(collateral_coin);
        let insertion_place = find_insertion_place<T>(protocol, insertion_place);
        let buck = buck::borrow<T>(
            protocol, oracle, clock, collateral_input, buck_output_amount, insertion_place, ctx
        );
        utils::transfer_non_zero_balance(buck, tx_context::sender(ctx), ctx);
    }

    public fun top_up<T>(
        protocol: &mut BucketProtocol,
        collateral_coin: Coin<T>,
        for: address,
        insertion_place: Option<address>,
        clock: &Clock,
    ) {
        let collateral_input = coin::into_balance(collateral_coin);
        let insertion_place = find_insertion_place<T>(protocol, insertion_place);
        buck::top_up_coll<T>(protocol, collateral_input, for, insertion_place, clock);
    }

    public fun repay_and_withdraw<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        buck_coin: Coin<BUCK>,
        coll_withdrawal_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        let debtor = tx_context::sender(ctx);
        let (_, debt_amount) = buck::get_bottle_info_with_interest_by_debtor<T>(protocol, debtor, clock);
        let buck_value = coin::value(&buck_coin);
        let buck_input = coin::into_balance(buck_coin);
        let buck_real_input = if (buck_value > debt_amount) {
            let buck_real_input = balance::split(&mut buck_input, debt_amount);
            utils::transfer_non_zero_balance(buck_input, debtor, ctx);
            buck_real_input
        } else {
            buck_input
        };
        let coll_output = buck::repay_debt<T>(protocol, buck_real_input, clock, ctx);
        let coll_output_amount = balance::value(&coll_output);
        let insertion_place = find_insertion_place<T>(protocol, insertion_place);
        if (coll_withdrawal_amount > coll_output_amount) {
            let extra_withdrawal_amount = coll_withdrawal_amount - coll_output_amount;
            let extra_coll_output = buck::withdraw<T>(protocol, oracle, clock, extra_withdrawal_amount, insertion_place, ctx);
            balance::join(&mut coll_output, extra_coll_output);
        } else if (coll_withdrawal_amount < coll_output_amount) {
            let topup_amount = coll_output_amount - coll_withdrawal_amount;
            let topup_coll_input = balance::split(&mut coll_output, topup_amount);
            buck::top_up_coll(protocol, topup_coll_input, debtor, insertion_place, clock);
        };
        
        utils::transfer_non_zero_balance(coll_output, debtor, ctx);
    }

    public fun repay_and_withdraw_with_strap<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        strap: &BottleStrap<T>,
        clock: &Clock,
        buck_coin: Coin<BUCK>,
        coll_withdrawal_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        let strap_addr = strap::get_address(strap);
        let debtor = tx_context::sender(ctx);
        let (_, debt_amount) = buck::get_bottle_info_with_interest_by_debtor<T>(protocol, strap_addr, clock);
        let buck_value = coin::value(&buck_coin);
        let buck_input = coin::into_balance(buck_coin);
        let buck_real_input = if (buck_value > debt_amount) {
            let buck_real_input = balance::split(&mut buck_input, debt_amount);
            utils::transfer_non_zero_balance(buck_input, debtor, ctx);
            buck_real_input
        } else {
            buck_input
        };
        let coll_output = buck::repay_with_strap<T>(protocol, strap, buck_real_input, clock);
        let coll_output_amount = balance::value(&coll_output);
        let insertion_place = find_insertion_place<T>(protocol, insertion_place);
        if (coll_withdrawal_amount > coll_output_amount) {
            let extra_withdrawal_amount = coll_withdrawal_amount - coll_output_amount;
            let extra_coll_output = buck::withdraw_with_strap<T>(protocol, oracle, strap, clock, extra_withdrawal_amount, insertion_place);
            balance::join(&mut coll_output, extra_coll_output);
        } else if (coll_withdrawal_amount < coll_output_amount) {
            let topup_amount = coll_output_amount - coll_withdrawal_amount;
            let topup_coll_input = balance::split(&mut coll_output, topup_amount);
            buck::top_up_coll(protocol, topup_coll_input, strap_addr, insertion_place, clock);
        };
        
        utils::transfer_non_zero_balance(coll_output, debtor, ctx);
    }

    public fun fully_repay<T>(
        protocol: &mut BucketProtocol,
        buck_coin: Coin<BUCK>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let debtor = tx_context::sender(ctx);
        let (_, debt_amount) = buck::get_bottle_info_with_interest_by_debtor<T>(protocol, debtor, clock);
        let buck_balance = coin::into_balance(buck_coin);
        let buck_input = balance::split(&mut buck_balance, debt_amount);
        let coll_output = buck::repay_debt<T>(protocol, buck_input, clock, ctx);
        utils::transfer_non_zero_balance(coll_output, debtor, ctx);
        utils::transfer_non_zero_balance(buck_balance, debtor, ctx);
    }

    public fun fully_repay_with_strap<T>(
        protocol: &mut BucketProtocol,
        strap: BottleStrap<T>,
        buck_coin: Coin<BUCK>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let debtor = tx_context::sender(ctx);
        let strap_addr = strap::get_address(&strap);
        let (_, debt_amount) = buck::get_bottle_info_with_interest_by_debtor<T>(protocol, strap_addr, clock);
        let buck_balance = coin::into_balance(buck_coin);
        let buck_input = balance::split(&mut buck_balance, debt_amount);
        let coll_output = buck::repay_with_strap<T>(protocol, &strap, buck_input, clock);
        utils::transfer_non_zero_balance(coll_output, debtor, ctx);
        utils::transfer_non_zero_balance(buck_balance, debtor, ctx);
        let bucket = buck::borrow_bucket<T>(protocol);
        bucket::destroy_empty_strap(bucket, strap);
    }

    public fun redeem<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        buck_coin: Coin<BUCK>,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        let buck_balance = coin::into_balance(buck_coin);
        let buck_value = balance::value(&buck_balance);
        let redemption_amount = redemption_amount<T>(protocol, clock, buck_value);
        let buck_input = balance::split(&mut buck_balance, redemption_amount);
        let collateral_return = buck::redeem<T>(protocol, oracle, clock, buck_input, insertion_place);
        utils::transfer_non_zero_balance(collateral_return, tx_context::sender(ctx), ctx);
        utils::transfer_non_zero_balance(buck_balance, tx_context::sender(ctx), ctx);
    }

    fun find_insertion_place<T>(
        protocol: &BucketProtocol,
        insertion_place: Option<address>,
    ): Option<address> {
        if (std::option::is_some(&insertion_place)) {
            let debtor = std::option::destroy_some(insertion_place);
            let bucket = buck::borrow_bucket<T>(protocol);
            if (bucket::bottle_exists(bucket, debtor)) {
                let bottle_table = bucket::borrow_bottle_table(bucket);
                let table = bottle::borrow_table(bottle_table);
                *linked_table::prev(table, debtor)
            } else {
                insertion_place
            }
        } else {
            insertion_place
        }
    }

    public fun redemption_amount<T>(
        protocol: &mut BucketProtocol,
        clock: &Clock,
        input_amount: u64,
    ): u64 {
        let bucket = buck::borrow_bucket<T>(protocol);
        let bottle_table = bucket::borrow_bottle_table(bucket);
        let table = bottle::borrow_table(bottle_table);
        let bucket_size = linked_table::length(table);
        if (bucket_size <= 500) return input_amount;
        let adjusted_amount = 0;
        let debtor_opt = *linked_table::front(table);
        while (option::is_some(&debtor_opt)) {
            let debtor = option::destroy_some(debtor_opt);
            let (_, debt_amount) = bucket::get_bottle_info_with_interest_by_debtor(
                bucket, debtor, clock,
            );
            if (input_amount >= debt_amount) {
                input_amount = input_amount - debt_amount;
                adjusted_amount = adjusted_amount + debt_amount;
                if (input_amount == 0) break
            } else {
                break
            };
            debtor_opt = *bucket::next_debtor(bucket, debtor);
        };
        adjusted_amount
    }

    public fun destroy_empty_strap<T>(
        protocol: &BucketProtocol,
        strap: BottleStrap<T>,
    ) {
        let bucket = buck::borrow_bucket<T>(protocol);
        bucket::destroy_empty_strap(bucket, strap);
    }

    public fun high_borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        collateral: Balance<T>,
        buck_output_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ): Balance<BUCK> {
        if (option::is_none(&insertion_place))
            insertion_place = last_debtor<T>(protocol);
        buck::borrow<T>(
            protocol, oracle, clock, collateral, buck_output_amount, insertion_place, ctx,
        )
    }

    public fun high_borrow_with_strap<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        strap: &BottleStrap<T>,
        clock: &Clock,
        collateral: Balance<T>,
        buck_output_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ): Balance<BUCK> {
        if (option::is_none(&insertion_place))
            insertion_place = last_debtor<T>(protocol);
        buck::borrow_with_strap<T>(
            protocol, oracle, strap, clock, collateral, buck_output_amount, insertion_place, ctx,
        )
    }

    public fun high_top_up<T>(
        protocol: &mut BucketProtocol,
        collateral: Balance<T>,
        for: address,
        insertion_place: Option<address>,
        clock: &Clock,
    ) {
        if (option::is_none(&insertion_place))
            insertion_place = last_debtor<T>(protocol);
        buck::top_up_coll(protocol, collateral, for, insertion_place, clock)
    }

    public fun last_debtor<T>(
        protocol: &BucketProtocol,
    ): Option<address> {
        let bucket = buck::borrow_bucket<T>(protocol);
        let bottle_table = bucket::borrow_bottle_table(bucket);
        let table = bottle::borrow_table(bottle_table);
        *linked_table::back(table)
    }
}
 