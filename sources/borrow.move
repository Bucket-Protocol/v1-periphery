module bucket_periphery::borrow {

    // Dependecies

    use std::vector;
    use std::option::Option;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::pay;
    use sui::balance;

    use bucket_protocol::buck::{Self, BucketProtocol};
    use bucket_protocol::mock_oracle::PriceFeed;
    use bucket_periphery::utils;

    public entry fun borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &PriceFeed<T>,
        collateral_coins: vector<Coin<T>>,
        collateral_amount: u64,
        output_buck_amount: u64,
        prev_debtor: Option<address>,
        ctx: &mut TxContext,
    ) {
        let collateral_coin = vector::pop_back(&mut collateral_coins);
        pay::join_vec(&mut collateral_coin, collateral_coins);
        let collateral_input = balance::split(coin::balance_mut(&mut collateral_coin), collateral_amount);

        let borrower = tx_context::sender(ctx);
        let buck = buck::borrow<T>(protocol, oracle, collateral_input, output_buck_amount, prev_debtor, ctx);

        utils::transfer_non_zero_balance(buck, borrower, ctx);
        utils::transfer_non_zero_coin(collateral_coin, borrower);
    }

    public entry fun auto_insert_borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &PriceFeed<T>,
        collateral_coins: vector<Coin<T>>,
        collateral_amount: u64,
        output_buck_amount: u64,
        ctx: &mut TxContext,
    ) {
        let collateral_coin = vector::pop_back(&mut collateral_coins);
        pay::join_vec(&mut collateral_coin, collateral_coins);
        let collateral_input = balance::split(coin::balance_mut(&mut collateral_coin), collateral_amount);

        let borrower = tx_context::sender(ctx);

        let buck = buck::auto_borrow(
            protocol, oracle, collateral_input, output_buck_amount, ctx
        );

        utils::transfer_non_zero_balance(buck, borrower, ctx);
        utils::transfer_non_zero_coin(collateral_coin, borrower);
    }

    #[test_only]
    use sui::sui::SUI;

    #[test]
    fun test_auto_insert_borrow(): BucketProtocol {
        use sui::test_scenario;
        use sui::test_utils;
        use bucket_protocol::mock_oracle;
        use bucket_protocol::buck::BUCK;
        use std::debug;

        let dev = @0xde1;
        let borrower_1 = @0x111;
        let borrower_2 = @0x222;

        let scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        let protocol = buck::new_for_testing(test_utils::create_one_time_witness<BUCK>(), test_scenario::ctx(scenario));
        let (oracle, ocap) = mock_oracle::new_for_testing<SUI>(2000, 1000, test_scenario::ctx(scenario));

        test_utils::print(b"--- Borrower 1 ---");

        let sui_input_amount = 1000000;
        let buck_output_amount = 1200000;

        test_scenario::next_tx(scenario, borrower_1);
        {
            let sui_input = balance::create_for_testing<SUI>(sui_input_amount * 3);
            let sui_input = vector[coin::from_balance(sui_input, test_scenario::ctx(scenario))];
            auto_insert_borrow(&mut protocol, &oracle, sui_input, sui_input_amount, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower_1);
        {
            let sui_remain = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let buck_output = test_scenario::take_from_sender<Coin<BUCK>>(scenario);
            debug::print(&sui_remain);
            debug::print(&buck_output);
            test_utils::assert_eq(coin::value(&sui_remain), sui_input_amount * 2);
            test_utils::assert_eq(coin::value(&buck_output), buck_output_amount);
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
            auto_insert_borrow(&mut protocol, &oracle, sui_input, sui_input_amount, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower_2);
        {
            let sui_remain = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let buck_coin_vec = test_scenario::ids_for_sender<Coin<BUCK>>(scenario);
            debug::print(&sui_remain);
            debug::print(&buck_coin_vec);
            test_utils::assert_eq(coin::value(&sui_remain), sui_input_amount / 2);
            test_utils::assert_eq(std::vector::length(&buck_coin_vec), 0);
            test_scenario::return_to_sender(scenario, sui_remain);
        };

        mock_oracle::destroy_for_testing(oracle, ocap);
        test_scenario::end(scenario_val);
        protocol
    }
}
