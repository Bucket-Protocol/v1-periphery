module bucket_periphery::bucket_operations {

    // Dependecies

    use std::option::Option;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;

    use switchboard_std::aggregator::Aggregator;
    // use bucket_oracle::bucket_oracle::{Self, BucketOracle};
    // use bucket_oracle::single_oracle;
    use bucket_oracle::bucket_oracle::BucketOracle;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_periphery::utils;

    public entry fun borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &mut BucketOracle,
        clock: &Clock,
        _switchboard_source: &Aggregator,
        collateral_coin: Coin<T>,
        buck_output_amount: u64,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        // TODO: no need to update on testnet
        // let single_oracle = bucket_oracle::borrow_single_oracle_mut<T>(oracle);
        // single_oracle::update_price_from_switchboard(single_oracle, clock, switchboard_source, ctx);

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
        buck_coin: Coin<BUCK>,
        ctx: &mut TxContext,
    ) {
        let buck_input = coin::into_balance(buck_coin);
        let collateral_return = buck::repay<T>(protocol, buck_input, ctx);

        utils::transfer_non_zero_balance(collateral_return, tx_context::sender(ctx), ctx);
    }

    public entry fun redeem<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        clock: &Clock,
        buck_coin: Coin<BUCK>,
        insertion_place: Option<address>,
        ctx: &mut TxContext,
    ) {
        // TODO: no need to update on testnet
        // let single_oracle = bucket_oracle::borrow_single_oracle_mut<T>(oracle);
        // single_oracle::update_price_from_switchboard(single_oracle, clock, switchboard_source, ctx);

        let buck_input = coin::into_balance(buck_coin);
        let collateral_return = buck::redeem<T>(protocol, oracle, clock, buck_input, insertion_place);
        utils::transfer_non_zero_balance(collateral_return, tx_context::sender(ctx), ctx);
    }
}
 