module bucket_periphery::repay {

    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::pay;
    use sui::tx_context::{Self, TxContext};

    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};
    use bucket_periphery::utils;

    const ENotEnoughBuck: u64 = 0;

    public entry fun repay<T>(
        protocol: &mut BucketProtocol,
        buck_coins: vector<Coin<BUCK>>,
        buck_amount: u64,
        ctx: &mut TxContext,
    ) {
        let debtor = tx_context::sender(ctx);
        let buck_coin = vector::pop_back(&mut buck_coins);
        pay::join_vec(&mut buck_coin, buck_coins);
        let (_, debt_amount) = buck::get_bottle_info<T>(protocol, debtor);
        if (debt_amount < buck_amount) {
            buck_amount = debt_amount;
        };

        assert!(coin::value(&buck_coin) >= buck_amount, ENotEnoughBuck);
        let buck_input = balance::split(coin::balance_mut(&mut buck_coin), buck_amount);
        let collateral_return = buck::repay<T>(protocol, buck_input, ctx);

        utils::transfer_non_zero_balance(collateral_return, debtor, ctx);
        utils::transfer_non_zero_coin(buck_coin, debtor);
    }

    #[test_only]
    use bucket_oracle::oracle::{Self, Oracle, AdminCap};

    #[test]
    fun test_repay(): (BucketProtocol, Oracle, AdminCap) {
        use sui::test_scenario;
        use sui::test_utils;
        use sui::sui::SUI;
        use bucket_protocol::buck::BUCK;
        use std::debug;
        use bucket_periphery::borrow;

        let dev = @0xde1;
        let borrower = @0x111;

        let scenario_val = test_scenario::begin(dev);
        let scenario = &mut scenario_val;

        let protocol = buck::new_for_testing(test_utils::create_one_time_witness<BUCK>(), test_scenario::ctx(scenario));
        let (oracle, ocap) = oracle::new_for_testing<SUI>(1000, test_scenario::ctx(scenario));

        let sui_input_amount = 1000000;
        let buck_output_amount = 1200000;

        test_scenario::next_tx(scenario, borrower);
        {
            oracle::update_price<SUI>(&ocap, &mut oracle, 2000);
            let sui_input = balance::create_for_testing<SUI>(sui_input_amount*3/2);
            let sui_coins = vector[coin::from_balance(sui_input, test_scenario::ctx(scenario))];
            borrow::auto_borrow(&mut protocol, &oracle, sui_coins, sui_input_amount, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower);
        {
            let buck_coins = vector[
                // borrowed buck
                test_scenario::take_from_sender<Coin<BUCK>>(scenario),
                // fee
                coin::from_balance(balance::create_for_testing<BUCK>(buck_output_amount * 5 / 1000), test_scenario::ctx(scenario)),
            ];
            repay<SUI>(&mut protocol, buck_coins, buck_output_amount, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, borrower);
        {
            let sui_return = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let buck_coin_ids = test_scenario::ids_for_sender<Coin<BUCK>>(scenario);
            debug::print(&sui_return);
            debug::print(&buck_coin_ids);
            test_utils::assert_eq(coin::value(&sui_return), sui_input_amount);
            test_utils::assert_eq(vector::length(&buck_coin_ids), 0);
            test_scenario::return_to_sender(scenario, sui_return);
        };

        test_scenario::end(scenario_val);
        (protocol, oracle, ocap)
    }
}
