module supervlabs::random {
    use std::vector;
    use std::error;
    use std::bcs;
    use std::hash;
    use std::signer;
    use aptos_std::from_bcs;

    const EINVALID_PSEUDO_RANDOM_RANGE: u64 = 3;

    struct RandInput has store, copy, drop {
        i1: address, i2: u64, i3: u64, i4: vector<u8>, min: u64, max: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct RandLog has key, copy, drop {
        list: vector<RandInput>,
    }

    struct RandOutput has store, drop {
        min: u64,
        max: u64,
        result: u64,
    }

    // A struct to store the output of Aptos Roll
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct RandOutputLog has key, drop {
        list: vector<RandOutput>,
    }

    #[view]
    /// Pseudo random number is generated in the range.
    public fun generate_u64(i1: address, i2: u64, i3: u64, i4: vector<u8>, min: u64, max: u64): u64 {
        let x = bcs::to_bytes<address>(&i1);
        vector::append(&mut x, bcs::to_bytes<u64>(&i2));
        vector::append(&mut x, bcs::to_bytes<u64>(&i3));
        vector::append(&mut x, i4);
        let hashvalue = hash::sha3_256(x);
        if (min == max) return min;
        assert!(min < max, error::invalid_argument(EINVALID_PSEUDO_RANDOM_RANGE));
        let u64vector = vector::trim(&mut hashvalue, 24);
        (from_bcs::to_u64(u64vector) % (max - min)) + min
    }

    #[view]
    /// Pseudo random number is generated in the range.
    public fun generate_u64_from_bytes_array(input: vector<vector<u8>>, min: u64, max: u64): u64 {
        let x = vector::empty();
        vector::for_each_ref(&input, |e| {
            vector::append(&mut x, *e);
        });
        let hashvalue = hash::sha3_256(x);
        if (min == max) return min;
        assert!(min < max, error::invalid_argument(EINVALID_PSEUDO_RANDOM_RANGE));
        let u64vector = vector::trim(&mut hashvalue, 24);
        (from_bcs::to_u64(u64vector) % (max - min)) + min
    }

    #[view]
    public fun replay_generated_u64(obj: address): (vector<RandInput>, vector<u64>) acquires RandLog {
        let log = borrow_global<RandLog>(obj);
        let loglist = log.list;
        let s: vector<u64> = vector[];
        vector::for_each_ref(&loglist, |e| {
            let ri: &RandInput = e;
            let roll = generate_u64(ri.i1, ri.i2, ri.i3, ri.i4, ri.min, ri.max);
            vector::push_back(&mut s, roll);
        });
        (loglist, s)
    }

    public fun store(obj_signer: &signer, i1: address, i2: u64, i3: u64, i4: vector<u8>, min: u64, max: u64) acquires RandLog {
        let obj_address = signer::address_of(obj_signer);
        if (exists<RandLog>(obj_address)) {
            vector::push_back(&mut borrow_global_mut<RandLog>(obj_address).list, RandInput {
                i1, i2, i3, i4, min, max
            });
        } else {
            move_to<RandLog>(obj_signer, RandLog {
                list: vector[RandInput { i1, i2, i3, i4, min, max}],
            });
        }
    }

    public fun store_roll_u64(obj_signer: &signer, result: u64, min: u64, max: u64) acquires RandOutputLog {
        let obj_address = signer::address_of(obj_signer);
        let output = RandOutput { min, max, result };
        if (exists<RandOutputLog>(obj_address)) {
            vector::push_back(&mut borrow_global_mut<RandOutputLog>(obj_address).list, output);
        } else {
            move_to<RandOutputLog>(obj_signer, RandOutputLog {
                list: vector[output],
            });
        }
    }
}