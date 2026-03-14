#![cfg_attr(not(feature = "std"), no_std)]
extern crate alloc;

use stylus_sdk::{alloy_primitives::{Address, B256}, prelude::*};

// Definición de almacenamiento compatible con la EVM de Arbitrum
sol_storage! {
    #[entrypoint]
    pub struct VaultChainMVP {
        // Mapeo optimizado: Usuario -> (FileHash -> IrysTxID)
        mapping(address => mapping(bytes32 => bytes32)) gallery;
    }
}

#[public]
impl VaultChainMVP {
    /// Registra el TxID de Irys vinculado al hash del archivo
    pub fn register_upload(&mut self, file_hash: B256, irys_tx_id: B256) -> Result<(), Vec<u8>> {
        // Obtenemos el sender usando el nuevo modelo de Host I/O
        let sender = self.vm().msg_sender();
        
        let mut user_files = self.gallery.setter(sender);
        
        // Verificamos deduplicación antes de escribir
        // Importante: Usamos.get() y.set() explícitos
        if user_files.getter(file_hash).get() == B256::ZERO {
            user_files.setter(file_hash).set(irys_tx_id);
        }
        
        Ok(())
    }

    /// Consulta el puntero de almacenamiento permanente
    pub fn get_file_ptr(&self, user: Address, file_hash: B256) -> B256 {
        self.gallery.getter(user).get(file_hash)
    }
}
