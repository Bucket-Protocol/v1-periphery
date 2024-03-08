module bucket_periphery::withdraw {

    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use bucket_protocol::buck::{Self, BucketProtocol};
    use bucket_protocol::bkt::BktAdminCap;
    use bucket_protocol::well;

    public fun withdraw_well<T>(
        cap: &BktAdminCap,
        protocol: &mut BucketProtocol,
        ctx: &mut TxContext,
    ): Coin<T> {
        let well = buck::borrow_well_mut<T>(protocol);
        let out = well::withdraw_reserve(cap, well);
        coin::from_balance(out, ctx)
    }
}