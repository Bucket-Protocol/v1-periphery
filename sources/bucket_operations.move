module bucket_periphery::bucket_operations {

    // Dependecies

    use std::option::Option;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;
    use sui::balance;

    use bucket_oracle::bucket_oracle::BucketOracle;
    use bucket_framework::math::mul_factor;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_periphery::utils;

    const ENotEnoughToWithdraw: u64 = 0;
    const ERepayTooMuch: u64 = 0;

    public entry fun borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        collateral_coin: Coin<T>,
        buck_output_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        let collateral_input = coin::into_balance(collateral_coin);
        let buck = buck::borrow<T>(
            protocol, oracle, clock, collateral_input, buck_output_amount, insertion_place, ctx
        );
        utils::transfer_non_zero_balance(buck, tx_context::sender(ctx), ctx);
    }

    public entry fun top_up<T>(
        protocol: &mut BucketProtocol,
        collateral_coin: Coin<T>,
        for: address,
        insertion_place: Option<address>,
    ) {
        let collateral_input = coin::into_balance(collateral_coin);
        buck::top_up<T>(protocol, collateral_input, for, insertion_place);
    }

    public entry fun repay<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        buck_coin: Coin<BUCK>,
        coll_withdrawal_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        let debtor = tx_context::sender(ctx);
        let buck_input = coin::into_balance(buck_coin);
        let buck_input_amount = balance::value(&buck_input);
        let (coll_amount, debt_amount) = buck::get_bottle_info_by_debtor<T>(protocol, debtor);
        assert!(coll_amount >= coll_withdrawal_amount, ENotEnoughToWithdraw);
        assert!(debt_amount >= buck_input_amount, ERepayTooMuch);
        let offset_debt_amount = mul_factor(debt_amount, coll_withdrawal_amount, coll_amount);
        
        let coll_withdrawal = if (offset_debt_amount > buck_input_amount) {
            let buck_diff = buck::borrow<T>(
                protocol,
                oracle,
                clock,
                balance::zero(),
                offset_debt_amount - buck_input_amount,
                insertion_place,
                ctx,
            );
            balance::join(&mut buck_input, buck_diff);
            buck::repay<T>(protocol, buck_input, ctx)
        } else if (offset_debt_amount < buck_input_amount) {
            let coll_output = buck::repay(protocol, buck_input, ctx);
            let coll_withdrawal = balance::split(&mut coll_output, coll_withdrawal_amount);
            buck::top_up(protocol, coll_output, debtor, insertion_place);
            coll_withdrawal
        } else {
            buck::repay<T>(protocol, buck_input, ctx)
        };
        utils::transfer_non_zero_balance(coll_withdrawal, debtor, ctx);
    }

    public fun purely_repay<T>(
        protocol: &mut BucketProtocol,
        buck_coin: Coin<BUCK>,
        ctx: &mut TxContext,
    ) {
        let buck_input = coin::into_balance(buck_coin);
        let coll_output = buck::repay<T>(protocol, buck_input, ctx);
        utils::transfer_non_zero_balance(coll_output, tx_context::sender(ctx), ctx);
    }

    public entry fun redeem<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        buck_coin: Coin<BUCK>,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        let buck_input = coin::into_balance(buck_coin);
        let collateral_return = buck::redeem<T>(protocol, oracle, clock, buck_input, insertion_place);
        utils::transfer_non_zero_balance(collateral_return, tx_context::sender(ctx), ctx);
    }
}
 