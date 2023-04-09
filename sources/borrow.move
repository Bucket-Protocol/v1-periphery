module bucket_periphery::borrow {

    // Dependecies

    use std::option::Option;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::Coin;

    use bucket_protocol::buck::{Self, BucketProtocol};
    use bucket_oracle::oracle::BucketOracle;
    use bucket_periphery::utils;

    public entry fun borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        collateral_coins: vector<Coin<T>>,
        collateral_amount: u64,
        output_buck_amount: u64,
        prev_debtor: Option<address>,
        ctx: &mut TxContext,
    ) {
        let (
            remaining,
            collateral_input
        ) = utils::merge_and_split_into_balance<T>(collateral_coins, collateral_amount);

        let borrower = tx_context::sender(ctx);
        let buck = buck::borrow<T>(
            protocol, oracle, collateral_input, output_buck_amount, prev_debtor, ctx
        );

        utils::transfer_non_zero_balance(buck, borrower, ctx);
        utils::transfer_non_zero_coin(remaining, borrower);
    }

    public entry fun auto_borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &BucketOracle,
        collateral_coins: vector<Coin<T>>,
        collateral_amount: u64,
        output_buck_amount: u64,
        ctx: &mut TxContext,
    ) {
        let (
            remaining,
            collateral_input
        ) = utils::merge_and_split_into_balance<T>(collateral_coins, collateral_amount);

        let borrower = tx_context::sender(ctx);
        let buck = buck::auto_borrow(
            protocol, oracle, collateral_input, output_buck_amount, ctx
        );

        utils::transfer_non_zero_balance(buck, borrower, ctx);
        utils::transfer_non_zero_coin(remaining, borrower);
    }

    #[test_only]
    use sui::sui::SUI;
    #[test_only]
    use bucket_oracle::oracle::{Self, AdminCap};
    #[test_only]
    use sui::coin;
    #[test_only]
    use sui::balance;

    #[test]
    fun test_auto_borrow(): (BucketProtocol, BucketOracle, AdminCap) {
        use sui::test_scenario;
        use sui::test_utils;
        use bucket_protocol::buck::BUCK;
        use std::debug;

        let dev = @0xde1;
        let borrower_1 = @0x111;
        let borrower_2 = @0x222;

        let scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        let protocol = buck::new_for_testing(test_utils::create_one_time_witness<BUCK>(), test_scenario::ctx(scenario));
        let (oracle, ocap) = oracle::new_for_testing<SUI>(1000, test_scenario::ctx(scenario));

        test_utils::print(b"--- Borrower 1 ---");

        let sui_input_amount = 1000000;
        let buck_output_amount = 1200000;

        test_scenario::next_tx(scenario, borrower_1);
        {
            oracle::update_price<SUI>(&ocap, &mut oracle, 2000);
            let sui_input = balance::create_for_testing<SUI>(sui_input_amount * 3);
            let sui_input = vector[coin::from_balance(sui_input, test_scenario::ctx(scenario))];
            auto_borrow(&mut protocol, &oracle, sui_input, sui_input_amount, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower_1);
        {
            let sui_remain = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let buck_output = test_scenario::take_from_sender<Coin<BUCK>>(scenario);
            debug::print(&sui_remain);
            debug::print(&buck_output);
            test_utils::assert_eq(coin::value(&sui_remain), sui_input_amount * 2);
            test_utils::assert_eq(coin::value(&buck_output), buck_output_amount * 995 / 1000);
            test_scenario::return_to_sender(scenario, sui_remain);
            test_scenario::return_to_sender(scenario, buck_output);
        };

        test_utils::print(b"--- Borrower 2 ---");

        let sui_input_amount = 2000;
        let buck_output_amount = 0;

        test_scenario::next_tx(scenario, borrower_2);
        {
            let sui_input = balance::create_for_testing<SUI>(sui_input_amount*3/2);
            let sui_input = vector[coin::from_balance(sui_input, test_scenario::ctx(scenario))];
            auto_borrow(&mut protocol, &oracle, sui_input, sui_input_amount, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower_2);
        {
            let sui_remain = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let buck_coin_ids = test_scenario::ids_for_sender<Coin<BUCK>>(scenario);
            debug::print(&sui_remain);
            debug::print(&buck_coin_ids);
            test_utils::assert_eq(coin::value(&sui_remain), sui_input_amount / 2);
            test_utils::assert_eq(std::vector::length(&buck_coin_ids),  0);
            test_scenario::return_to_sender(scenario, sui_remain);
        };

        test_scenario::end(scenario_val);
        (protocol, oracle, ocap)
    }
}
