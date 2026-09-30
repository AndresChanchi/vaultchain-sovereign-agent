//! Cross-contract interfaces consumed by `kipio_account`.

use stylus_sdk::prelude::sol_interface;

sol_interface! {
    interface IKipioRecovery {
        function consumeRecovery(
            address account,
            bytes32 request_id,
            bytes32 effects_hash
        ) external;
    }
}
