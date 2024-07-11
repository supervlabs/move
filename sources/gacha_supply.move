/// This module provides the grade-based supply management of Supervlabs Gacha system.
/// The maximum number of token minting will be limited by this module for the target grade.
module supervlabs::gacha_supply {
    use std::vector;
    use std::error;
    use std::signer;
    use std::string::{Self, String};

    const EGACHA_LIMITEDSUPPLY_OBJECT_NOT_FOUND: u64 = 1;
    const EGACHA_SUPPLY_INFO_NOT_FOUND: u64 = 2;

    struct SupplyInfo has copy, drop, store {
        id : String,
        grade: String,
        max: u64,
        current: u64,
        add_info: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct GachaLimitedSupply has key, copy, drop {
        list: vector<SupplyInfo>,
    }

    public fun new_supply(id: String, grade: String, add_info: u64, max: u64, current: u64): SupplyInfo {
        SupplyInfo { id, grade, add_info, max, current }
    }

    public fun init(
        obj_signer: &signer,
        supply_info: vector<SupplyInfo>
    ) acquires GachaLimitedSupply {
        let obj_address = signer::address_of(obj_signer);
        if (!exists<GachaLimitedSupply>(obj_address)) {
            move_to(obj_signer, GachaLimitedSupply {
                list: supply_info,
            });
        } else {
            let supply = borrow_global_mut<GachaLimitedSupply>(obj_address);
            supply.list = supply_info;
        }
    }

    public fun exists_at(obj_address: address): bool {
        exists<GachaLimitedSupply>(obj_address)
    }

    public fun replace(obj_signer: &signer, supply_info: SupplyInfo) acquires GachaLimitedSupply {
        let obj_address = signer::address_of(obj_signer);
        assert!(
            exists<GachaLimitedSupply>(obj_address),
            error::invalid_argument(EGACHA_LIMITEDSUPPLY_OBJECT_NOT_FOUND),
        );
        let supply = borrow_global_mut<GachaLimitedSupply>(obj_address);
        let i = 0;
        let len = vector::length(&supply.list);
        let new_id = string::bytes(&supply_info.id);
        while (i < len) {
            let info = vector::borrow(&supply.list, i);
            if (string::bytes(&info.id) == new_id) {
                let info = vector::borrow_mut(&mut supply.list, i);
                *info = supply_info;
                break
            };
            i = i + 1;
        };
        assert!(i < len, error::invalid_argument(EGACHA_SUPPLY_INFO_NOT_FOUND));
    }

    public fun increase(obj_address: address, index: u64, amount: u64) acquires GachaLimitedSupply {
        assert!(
            exists<GachaLimitedSupply>(obj_address),
            error::invalid_argument(EGACHA_LIMITEDSUPPLY_OBJECT_NOT_FOUND),
        );
        let supply = borrow_global_mut<GachaLimitedSupply>(obj_address);
        let len = vector::length(&supply.list);
        assert!(index < len, error::invalid_argument(EGACHA_SUPPLY_INFO_NOT_FOUND));
        let info = vector::borrow_mut(&mut supply.list, index);
        info.current = info.current + amount;
    }

    public fun get(obj_address: address, index: u64): SupplyInfo acquires GachaLimitedSupply {
        if (exists<GachaLimitedSupply>(obj_address)) {
            let supply = borrow_global<GachaLimitedSupply>(obj_address);
            let len = vector::length(&supply.list);
            assert!(index < len, error::invalid_argument(EGACHA_SUPPLY_INFO_NOT_FOUND));
            let info = vector::borrow(&supply.list, index);
            *info
        } else {
            let empty = string::utf8(b"");
            new_supply(empty, empty, 0, 0, 0)
        }
    }

    public fun check_run_out(supply_info: &SupplyInfo): bool {
        supply_info.current >= supply_info.max
    }

    public fun get_grade(supply_info: &SupplyInfo): String {
        supply_info.grade
    }

    public fun get_add_info(supply_info: &SupplyInfo): u64 {
        supply_info.add_info
    }
}