module bucket_periphery::redeem {

    use sui::coin::Coin;
    use sui::tx_context::TxContext;

    use bucket_oracle::oracle::BucketOracle;
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_periphery::utils;
    use sui::tx_context;

    public entry fun auto_redeem<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        buck_coins: vector<Coin<BUCK>>,
        buck_amount: u64,
        ctx: &mut TxContext,
    ) {
        let (
            remaining,
            buck_input
        ) = utils::merge_and_split_into_balance(buck_coins, buck_amount);

        let redeemer = tx_context::sender(ctx);
        let collateral_return = buck::auto_redeem<T>(protocol, oracle, buck_input);

        utils::transfer_non_zero_balance(collateral_return, redeemer, ctx);
        utils::transfer_non_zero_coin(remaining, redeemer);
    }

    #[test_only]
    use bucket_oracle::oracle::{Self, AdminCap};
    #[test_only]
    use sui::balance;
    #[test_only]
    use sui::coin;
    #[test_only]
    use sui::pay;

    #[test]
    fun test_auto_redeem(): (BucketProtocol, BucketOracle, AdminCap) {
        use sui::test_scenario;
        use sui::test_utils;
        use sui::sui::SUI;
        use std::vector;
        use bucket_protocol::buck::BUCK;
        use std::debug;
        use bucket_periphery::borrow;

        let dev = @0xde1;
        let borrower = @0x111;
        let redeemer = @0x222;

        let scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        let protocol = buck::new_for_testing(test_utils::create_one_time_witness<BUCK>(), test_scenario::ctx(scenario));
        let (oracle, ocap) = oracle::new_for_testing<SUI>(1000, test_scenario::ctx(scenario));

        let sui_input_amount = 1000000;
        let buck_output_amount = 1200000;
        let buck_transfer_amount = buck_output_amount / 2;

        test_scenario::next_tx(scenario, borrower);
        {
            oracle::update_price<SUI>(&ocap, &mut oracle, 2000);
            let sui_input = balance::create_for_testing<SUI>(sui_input_amount*3/2);
            let sui_coins = vector[coin::from_balance(sui_input, test_scenario::ctx(scenario))];
            borrow::auto_borrow(&mut protocol, &oracle, sui_coins, sui_input_amount, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower);
        {

            let borrowed_buck = test_scenario::take_from_sender<Coin<BUCK>>(scenario);
            pay::split_and_transfer(&mut borrowed_buck, buck_transfer_amount, redeemer, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, borrowed_buck);
        };

        test_scenario::next_tx(scenario, redeemer);
        {
            oracle::update_price<SUI>(&ocap, &mut oracle, 4000);
            let buck_coin = test_scenario::take_from_sender<Coin<BUCK>>(scenario);
            auto_redeem<SUI>(&mut protocol, &oracle, vector[buck_coin], buck_transfer_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, redeemer);
        {
            let (price, denominator) = oracle::get_price<SUI>(&oracle);
            let buck_coin_ids = test_scenario::ids_for_sender<Coin<BUCK>>(scenario);
            test_utils::assert_eq(vector::length(&buck_coin_ids), 0);
            let sui_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            debug::print(&sui_coin);
            let sui_value = coin::value(&sui_coin) * price / denominator;
            test_utils::assert_eq(sui_value, buck_transfer_amount * 995 / 1000);
            test_scenario::return_to_sender(scenario, sui_coin);
        };

        test_scenario::end(scenario_val);

        (protocol, oracle, ocap)
    }
}
