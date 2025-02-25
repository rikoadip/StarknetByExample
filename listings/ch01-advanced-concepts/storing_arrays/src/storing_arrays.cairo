use starknet::{
    StorageBaseAddress, Store, SyscallResult, storage_read_syscall, storage_write_syscall,
    storage_address_from_base_and_offset
};

// ANCHOR: StorageAccessImpl
impl StoreFelt252Array of Store<Array<felt252>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<felt252>> {
        StoreFelt252Array::read_at_offset(address_domain, base, 0)
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Array<felt252>
    ) -> SyscallResult<()> {
        StoreFelt252Array::write_at_offset(address_domain, base, 0, value)
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8
    ) -> SyscallResult<Array<felt252>> {
        let mut arr: Array<felt252> = ArrayTrait::new();

        // Read the stored array's length. If the length is superior to 255, the read will fail.
        let len: u8 = Store::<u8>::read_at_offset(address_domain, base, offset)
            .expect('Storage Span too large');
        offset += 1;

        // Sequentially read all stored elements and append them to the array.
        let exit = len + offset;
        loop {
            if offset >= exit {
                break;
            }

            let value = Store::<felt252>::read_at_offset(address_domain, base, offset).unwrap();
            arr.append(value);
            offset += Store::<felt252>::size();
        };

        // Return the array.
        Result::Ok(arr)
    }

    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8, mut value: Array<felt252>
    ) -> SyscallResult<()> {
        // // Store the length of the array in the first storage slot.
        let len: u8 = value.len().try_into().expect('Storage - Span too large');
        Store::<u8>::write_at_offset(address_domain, base, offset, len);
        offset += 1;

        // Store the array elements sequentially
        loop {
            match value.pop_front() {
                Option::Some(element) => {
                    Store::<felt252>::write_at_offset(address_domain, base, offset, element);
                    offset += Store::<felt252>::size();
                },
                Option::None(_) => {
                    break Result::Ok(());
                }
            };
        }
    }

    fn size() -> u8 {
        255 * Store::<felt252>::size()
    }
}
// ANCHOR_END: StorageAccessImpl

// ANCHOR: StoreArrayContract
#[starknet::contract]
mod StoreArrayContract {
    use super::StoreFelt252Array;

    #[storage]
    struct Storage {
        arr: Array<felt252>
    }

    #[generate_trait]
    #[external(v0)]
    impl StoreArrayImpl of IStoreArrayContract {
        fn store_array(ref self: ContractState, arr: Array<felt252>) {
            self.arr.write(arr);
        }

        fn read_array(self: @ContractState) -> Array<felt252> {
            self.arr.read()
        }
    }
}
// ANCHOR_END: StoreArrayContract

#[starknet::interface]
trait IStoreArrayContract<TContractState> {
    fn store_array(ref self: TContractState, array: Array<felt252>);
    fn read_array(self: @TContractState) -> Array<felt252>;
}

#[cfg(test)]
mod tests {
    use super::StoreArrayContract;
    use super::{IStoreArrayContractDispatcher, IStoreArrayContractDispatcherTrait};
    use starknet::deploy_syscall;
    use starknet::class_hash::Felt252TryIntoClassHash;

    #[test]
    #[available_gas(20000000)]
    fn test_array_storage() {
        // Set up.
        let mut calldata: Array<felt252> = ArrayTrait::new();
        let (address0, _) = deploy_syscall(
            StoreArrayContract::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        let mut contract = IStoreArrayContractDispatcher { contract_address: address0 };

        // Store an array.
        let mut array: Array<felt252> = ArrayTrait::new();
        array.append(1);
        array.append(2);
        contract.store_array(array);

        // Read the array.
        let read_array = contract.read_array();
        assert(read_array.len() == 2, 'Array length mismatch');
        assert(*read_array[0] == 1, 'Array element mismatch');
        assert(*read_array[1] == 2, 'Array element mismatch');
    }

    #[test]
    #[available_gas(20000000000)]
    #[should_panic(expected: ('Storage - Span too large', 'ENTRYPOINT_FAILED'))]
    fn test_array_storage_too_large() {
        // Set up.
        let mut calldata: Array<felt252> = ArrayTrait::new();
        let (address0, _) = deploy_syscall(
            StoreArrayContract::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        let mut contract = IStoreArrayContractDispatcher { contract_address: address0 };

        // Store an array.
        let mut array: Array<felt252> = ArrayTrait::new();
        let mut i = 0;
        loop {
            if i == 256 {
                break ();
            }
            array.append(i);
            i += 1;
        };
        contract.store_array(array);

        // Read the array.
        let read_array = contract.read_array();
        assert(read_array.len() == 2, 'Array too large');
        assert(*read_array[0] == 1, 'Array element mismatch');
        assert(*read_array[1] == 2, 'Array element mismatch');
    }
}
