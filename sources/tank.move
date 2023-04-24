module bucket_periphery::tank {

    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use bucket_protocol::buck::BUCK;
    use bucket_protocol::tank::{Self, Tank, TankToken};
    use bucket_protocol::bkt::BktTreasury;

    public entry fun deposit<T>(
        clock: &Clock,
        tank: &mut Tank<BUCK, T>,
        buck_coin: Coin<BUCK>,
        ctx: &mut TxContext,
    ) {
        let buck_input = coin::into_balance(buck_coin);
        let tank_token = tank::deposit(clock, tank, buck_input, ctx);
        transfer::public_transfer(tank_token, tx_context::sender(ctx));
    }

    public entry fun withdraw<T>(
        clock: &Clock,
        tank: &mut Tank<BUCK, T>,
        bkt_treasury: &mut BktTreasury,
        tank_token: TankToken<BUCK, T>,
        ctx: &mut TxContext,
    ) {
        let (buck_output, collateral, bkt_output) = tank::withdraw(
            clock, tank, bkt_treasury, tank_token,
        );
        let user = tx_context::sender(ctx);
        transfer::public_transfer(coin::from_balance(buck_output, ctx), user);
        transfer::public_transfer(coin::from_balance(collateral, ctx), user);
        transfer::public_transfer(coin::from_balance(bkt_output, ctx), user);
    }
    
    public entry fun claim<T>(
        clock: &Clock,
        bkt_treasury: &mut BktTreasury,
        tank_token: &mut TankToken<BUCK, T>,
        ctx: &mut TxContext,
    ) {
        let bkt_output = tank::claim(clock, bkt_treasury, tank_token);
        transfer::public_transfer(coin::from_balance(bkt_output, ctx), tx_context::sender(ctx));
    }
}