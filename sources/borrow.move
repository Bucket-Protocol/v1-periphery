module bucket_periphery::borrow {

    // Dependecies

    use std::vector;
    use std::option::Option;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::pay;
    use sui::balance;

    use bucket_protocol::buck::{Self, BucketProtocol};
    use bucket_protocol::mock_oracle::PriceFeed;

    public entry fun borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &PriceFeed<T>,
        collateral_coins: vector<Coin<T>>,
        collateral_amount: u64,
        expected_buck_amount: u64,
        prev_debtor: Option<address>,
        ctx: &mut TxContext,
    ) {
        let sui_coin = vector::pop_back(&mut collateral_coins);
        pay::join_vec(&mut sui_coin, collateral_coins);
        let sui_input = balance::split(coin::balance_mut(&mut sui_coin), collateral_amount);

        let borrower = tx_context::sender(ctx);
        let buck = buck::borrow<T>(protocol, oracle, sui_input, expected_buck_amount, prev_debtor, ctx);
        transfer::public_transfer(coin::from_balance(buck, ctx), borrower);
        transfer::public_transfer(sui_coin, borrower);
    }

    public entry fun auto_insert_borrow<T>(
        protocol: &mut BucketProtocol,
        oracle: &PriceFeed<T>,
        collateral_coins: vector<Coin<T>>,
        collateral_amount: u64,
        expected_buck_amount: u64,
        ctx: &mut TxContext,
    ) {
        let sui_coin = vector::pop_back(&mut collateral_coins);
        pay::join_vec(&mut sui_coin, collateral_coins);
        let sui_input = balance::split(coin::balance_mut(&mut sui_coin), collateral_amount);

        let borrower = tx_context::sender(ctx);

        let buck = buck::auto_insert_borrow(
            protocol, oracle, sui_input, expected_buck_amount, ctx
        );
        transfer::public_transfer(coin::from_balance(buck, ctx), borrower);
        transfer::public_transfer(sui_coin, borrower);
    }

    #[test_only]
    use bucket_protocol::well::{Well};
    
    #[test_only]
    use sui::sui::SUI;

    #[test]
    fun test_auto_insert_borrow(): (BucketProtocol, Well<SUI>) {
        use sui::test_scenario;
        use sui::test_utils;
        use bucket_protocol::mock_oracle;
        use bucket_protocol::buck::BUCK;
        use std::debug;

        let dev = @0xde1;
        let borrower = @0x111;

        let scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        let (protocol, well) = buck::new_for_testing(test_utils::create_one_time_witness<BUCK>(), test_scenario::ctx(scenario));
        let (oracle, ocap) = mock_oracle::new_for_testing<SUI>(2000, 1000, test_scenario::ctx(scenario));

        let sui_input_amount = 1000000;
        let buck_output_amount = 1200000;

        test_scenario::next_tx(scenario, borrower);
        {
            let sui_input = balance::create_for_testing<SUI>(sui_input_amount * 3);
            let sui_input = vector[coin::from_balance(sui_input, test_scenario::ctx(scenario))];
            auto_insert_borrow(&mut protocol, &oracle, sui_input, sui_input_amount, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower);
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

        mock_oracle::destroy_for_testing(oracle, ocap);
        test_scenario::end(scenario_val);
        (protocol, well)
    }
}
