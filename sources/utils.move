module bucket_periphery::utils;

use bucket_framework::linked_table;
use bucket_protocol::bottle;
use bucket_protocol::buck::{Self, BucketProtocol};
use bucket_protocol::bucket;
use std::vector as vec;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};

public fun transfer_non_zero_coin<T>(coin: Coin<T>, recipient: address) {
    if (coin::value(&coin) == 0) {
        coin::destroy_zero(coin);
    } else {
        transfer::public_transfer(coin, recipient);
    }
}

public fun transfer_non_zero_balance<T>(
    balance: Balance<T>,
    recipient: address,
    ctx: &mut TxContext,
) {
    if (balance::value(&balance) == 0) {
        balance::destroy_zero(balance);
    } else {
        transfer::public_transfer(coin::from_balance(balance, ctx), recipient);
    }
}

public struct BottleData has copy, drop {
    debtor: address,
    coll_amount: u64,
    debt_amount: u64,
}

public fun get_bottles<T>(
    protocol: &BucketProtocol,
    clock: &Clock,
    mut cursor: Option<address>,
    page_size: u64,
): (vector<BottleData>, Option<address>) {
    let mut bottle_vec = vector<BottleData>[];
    let bucket = buck::borrow_bucket<T>(protocol);
    if (option::is_none(&cursor)) {
        cursor = bucket::get_lowest_cr_debtor(bucket);
    };
    let mut counter = 0;
    while (option::is_some(&cursor) && counter < page_size) {
        let debtor = *option::borrow(&cursor);
        let (coll_amount, debt_amount) = bucket::get_bottle_info_with_interest_by_debtor(
            bucket,
            debtor,
            clock,
        );
        vec::push_back(
            &mut bottle_vec,
            BottleData {
                debtor,
                coll_amount,
                debt_amount,
            },
        );
        counter = counter + 1;
        cursor = *bucket::next_debtor(bucket, debtor);
    };
    (bottle_vec, cursor)
}

// public fun get_debtor_bottles_in_locker<T>(
//     protocol: &BucketProtocol,
//     clock: &Clock,
//     locker:
//     debtor: address,
// )

#[test]
fun test_transfer_non_zero() {
    use sui::test_scenario;
    use sui::sui::SUI;
    use std::debug;

    let sender = @0xde1;
    let recipient_1 = @0x111;
    let recipient_2 = @0x222;

    let mut scenario_val = test_scenario::begin(sender);
    let scenario = &mut scenario_val;

    let transfer_amount = 1000;

    test_scenario::next_tx(scenario, sender);
    {
        let sui_balance_0 = balance::create_for_testing<SUI>(0);
        let sui_balance_1 = balance::create_for_testing<SUI>(transfer_amount);
        transfer_non_zero_balance(sui_balance_0, recipient_1, test_scenario::ctx(scenario));
        transfer_non_zero_balance(sui_balance_1, recipient_1, test_scenario::ctx(scenario));
    };

    test_scenario::next_tx(scenario, recipient_1);
    {
        let sui_coin_ids = test_scenario::ids_for_sender<Coin<SUI>>(scenario);
        debug::print(&sui_coin_ids);
        assert!(vector::length(&sui_coin_ids) == 1, 0);
        let coin_id = *vector::borrow(&sui_coin_ids, 0);
        let sui_coin = test_scenario::take_from_sender_by_id<Coin<SUI>>(scenario, coin_id);
        debug::print(&sui_coin);
        assert!(coin::value(&sui_coin) == transfer_amount, 1);
        test_scenario::return_to_sender(scenario, sui_coin);
    };

    let transfer_amount = 2500;

    test_scenario::next_tx(scenario, sender);
    {
        let sui_coin_0 = coin::from_balance(
            balance::create_for_testing<SUI>(transfer_amount),
            test_scenario::ctx(scenario),
        );
        let sui_coin_1 = coin::from_balance(
            balance::create_for_testing<SUI>(0),
            test_scenario::ctx(scenario),
        );

        transfer_non_zero_coin(sui_coin_0, recipient_2);
        transfer_non_zero_coin(sui_coin_1, recipient_2);
    };

    test_scenario::next_tx(scenario, recipient_2);
    {
        let sui_coin_ids = test_scenario::ids_for_sender<Coin<SUI>>(scenario);
        debug::print(&sui_coin_ids);
        assert!(vector::length(&sui_coin_ids) == 1, 0);
        let coin_id = *vector::borrow(&sui_coin_ids, 0);
        let sui_coin = test_scenario::take_from_sender_by_id<Coin<SUI>>(scenario, coin_id);
        debug::print(&sui_coin);
        assert!(coin::value(&sui_coin) == transfer_amount, 1);
        test_scenario::return_to_sender(scenario, sui_coin);
    };

    test_scenario::end(scenario_val);
}

public fun get_bottles_by_step<T>(
    protocol: &BucketProtocol,
    clock: &Clock,
    mut cursor: Option<address>,
    step_size: u64,
    limit: u64,
): (vector<BottleData>, Option<address>) {
    let mut bottle_vec = vector<BottleData>[];
    let bucket = buck::borrow_bucket<T>(protocol);
    if (option::is_none(&cursor)) {
        cursor = bucket::get_lowest_cr_debtor(bucket);
    };
    let mut total_counter = 0;
    while (option::is_some(&cursor) && total_counter < limit) {
        let debtor = *option::borrow(&cursor);
        cursor = *bucket::next_debtor(bucket, debtor);
        if (total_counter % step_size == 0) {
            let (coll_amount, debt_amount) = bucket::get_bottle_info_with_interest_by_debtor(
                bucket,
                debtor,
                clock,
            );
            vec::push_back(
                &mut bottle_vec,
                BottleData {
                    debtor,
                    coll_amount,
                    debt_amount,
                },
            );
        };
        total_counter = total_counter + 1;
    };
    (bottle_vec, cursor)
}

public fun get_bottles_with_direction<T>(
    protocol: &BucketProtocol,
    clock: &Clock,
    mut cursor: Option<address>,
    step_size: u64,
    limit: u64,
    upward: bool,
): (vector<BottleData>, Option<address>) {
    let mut bottle_vec = vector<BottleData>[];
    let bucket = buck::borrow_bucket<T>(protocol);
    if (option::is_none(&cursor)) {
        cursor = if (upward) {
                bucket::get_lowest_cr_debtor(bucket)
            } else {
                let bottle_table = bucket::borrow_bottle_table(bucket);
                let table = bottle::borrow_table(bottle_table);
                *linked_table::back(table)
            };
    };
    let mut total_counter = 0;
    while (option::is_some(&cursor) && total_counter < limit) {
        let debtor = *option::borrow(&cursor);
        cursor = if (upward) {
                *bucket::next_debtor(bucket, debtor)
            } else {
                *bucket::prev_debtor(bucket, debtor)
            };
        if (total_counter % step_size == 0 || option::is_none(&cursor)) {
            let (coll_amount, debt_amount) = bucket::get_bottle_info_with_interest_by_debtor(
                bucket,
                debtor,
                clock,
            );
            vec::push_back(
                &mut bottle_vec,
                BottleData {
                    debtor,
                    coll_amount,
                    debt_amount,
                },
            );
        };
        total_counter = total_counter + 1;
    };
    (bottle_vec, cursor)
}
