module bucket_periphery::add_interest {

    use std::option::{Self, Option};
    use sui::tx_context::{TxContext};
    use sui::clock::{Clock};
    use sui::event;
    use bucket_framework::linked_table;
    use bucket_protocol::buck::{Self, AdminCap, BucketProtocol};
    use bucket_protocol::bucket;
    use bucket_protocol::bottle;

    struct NextCursor<phantom T> has copy, drop {
        cursor: Option<address>,
    }

    public fun add_interest<T>(
        cap: &AdminCap,
        protocol: &mut BucketProtocol,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        buck::add_pending_record_to_bucket<T>(cap, protocol, ctx);
        buck::add_interest_table_to_bucket<T>(cap, protocol, clock, ctx);
    }

    public fun init_bottles<T>(
        cap: &AdminCap,
        protocol: &mut BucketProtocol,
        cursor: Option<address>,
        count: u64,
        ctx: &mut TxContext,
    ) {
        let idx = 0;
        if (option::is_none(&cursor)) {
            cursor = front<T>(protocol);
        };
        while (idx < count && option::is_some(&cursor)) {
            let debtor = option::destroy_some(cursor);
            buck::init_bottle_current_interest_index<T>(
                cap, protocol, debtor, ctx,
            );
            let bucket = buck::borrow_bucket<T>(protocol);
            cursor = *bucket::next_debtor(bucket, debtor);
            idx = idx + 1;
        };
        event::emit(NextCursor<T> { cursor });
    }

    public fun add_interest_and_init_bottles<T>(
        cap: &AdminCap,
        protocol: &mut BucketProtocol,
        clock: &Clock,
        interest_rate: u256,
        ctx: &mut TxContext,
    ) {
        add_interest<T>(cap, protocol, clock, ctx);
        init_bottles<T>(cap, protocol, option::none(), 500, ctx);
        buck::set_interest_rate<T>(cap, protocol, interest_rate, clock);
    }

    public fun front<T>(protocol: &BucketProtocol): Option<address> {
        let bucket = buck::borrow_bucket<T>(protocol);
        let bottle_table = bucket::borrow_bottle_table(bucket);
        let table = bottle::borrow_table(bottle_table);
        *linked_table::front(table)
    }
}