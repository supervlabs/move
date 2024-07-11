module supervlabs::sidekick_fusion {
    use std::error;
    use std::vector;
    use std::option;
    use std::signer;
    use std::string::{Self, String, utf8};
    use aptos_framework::object;
    use aptos_token_objects::property_map;

    use apto_orm::orm_class;
    use apto_orm::orm_creator;
    use apto_orm::orm_module;
    use apto_orm::orm_object;
    use supervlabs::sidekick::{Self, Sidekick};
    use supervlabs::gacha_probability::{Self, GachaProbabilitySet};

    const ENOT_TWO_PAIRS_SIDEKICK: u64 = 1;
    const EPAIR_HAS_DIFFERENT_GRADE: u64 = 2;
    const ESIDEKICK_FUNSION_PROBABILITY_NOT_FOUND: u64 = 3;
    const ESIDEKICK_OBJECT_NOT_FOUND: u64 = 4;
    const EFUSION_NOT_SUPPORTED_FOR_GRADE: u64 = 5;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct SidekickFusion has key, drop, copy {
        probabilities: vector<GachaProbabilitySet>,
    }

    fun init(account_or_object: &signer, probabilities: vector<GachaProbabilitySet>) {
        move_to<SidekickFusion>(account_or_object, SidekickFusion { probabilities });
    }

    fun init_module(package: &signer) acquires SidekickFusion {
        let fusion = SidekickFusion {
            probabilities: vector[
                gacha_probability::new(
                    utf8(b"common_fusion"),
                    vector[utf8(b"legendary"), utf8(b"epic"), utf8(b"rare"), utf8(b"uncommon"), utf8(b"common")],
                    vector[utf8(b"0.001"), utf8(b"0.008"), utf8(b"0.05"), utf8(b"0.3"), utf8(b"0.641")],
                ),
                gacha_probability::new(
                    utf8(b"uncommon_fusion"),
                    vector[utf8(b"legendary"), utf8(b"epic"), utf8(b"rare"), utf8(b"uncommon")],
                    vector[utf8(b"0.0025"), utf8(b"0.0201"), utf8(b"0.1253"), utf8(b"0.8521")],
                ),
                gacha_probability::new(
                    utf8(b"rare_fusion"),
                    vector[utf8(b"legendary"), utf8(b"epic"), utf8(b"rare")],
                    vector[utf8(b"0.0153"), utf8(b"0.1220"), utf8(b"0.8627")],
                ),
                gacha_probability::new(
                    utf8(b"epic_fusion"),
                    vector[utf8(b"legendary"), utf8(b"epic")],
                    vector[utf8(b"0.10"), utf8(b"0.90")],
                ),
            ]
        };
        let (_orm_creator, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        if (orm_class::has_class_signer(orm_class)) {
            let class_signer = orm_class::load_class_signer(package, orm_class);
            let class_address = signer::address_of(&class_signer);
            if (exists<SidekickFusion>(class_address)) {
                move_from<SidekickFusion>(class_address);
            };
            move_to(&class_signer, fusion);
        } else {
            let package_address = signer::address_of(package);
            if (exists<SidekickFusion>(package_address)) {
                move_from<SidekickFusion>(package_address);
            };
            move_to(package, fusion);
        };
    }

    entry fun update_module(user: &signer) acquires SidekickFusion {
        let (orm_creator, _orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let creator = orm_creator::load_creator(user, orm_creator);
        init_module(&creator);
    }

    fun fuse_sidekick(
        creator: &signer,
        pset: &GachaProbabilitySet,
        left: &address,
        _right: &address,
        salt: u64,
        to: address
    ): object::ConstructorRef {
        let (grades, numerators) =
            gacha_probability::get_probabilities(pset, 100000000);
        let (ref, _) = sidekick::create_object(
            creator, *left, salt, option::some(to),
            grades, numerators, 100000000,
        );
        ref
    }

    fun to_lower(s: &String): String {
        let len = string::length(s);
        let bytes = string::bytes(s);
        let i = 0;
        let output = vector::empty<u8>();
        while (i < len) {
            let c = *vector::borrow(bytes, i);
            if (c >= 65 && c <= 90) {
                vector::push_back(&mut output, c + 32);
            } else {
                vector::push_back(&mut output, c);
            };
            i = i + 1;
        };
        string::utf8(output)
    }

    #[randomness]
    entry fun fuse_sidekicks(
        package_owner: &signer,
        sidekicks: vector<address>,
        salt: u64,
        to: address,
    ) acquires SidekickFusion {
        let len = vector::length(&sidekicks);
        assert!(len%2 == 0 && len > 1, error::invalid_argument(ENOT_TWO_PAIRS_SIDEKICK));
        let (orm_creator, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let creator = orm_creator::load_creator(package_owner, orm_creator);
        let fusion_address = object::object_address(&orm_class);
        if (!exists<SidekickFusion>(fusion_address)) {
            fusion_address = signer::address_of(&creator);
            assert!(
                exists<SidekickFusion>(fusion_address),
                error::not_found(ESIDEKICK_FUNSION_PROBABILITY_NOT_FOUND)
            );
        };
        let fusion = borrow_global<SidekickFusion>(fusion_address);
        let i = 0;
        let grade_str = utf8(b"grade");
        let epic_str = utf8(b"epic");
        let rare_str = utf8(b"rare");
        let uncommon_str = utf8(b"uncommon");
        let common_str = utf8(b"common");
        while (i < len) {
            let left = vector::borrow(&sidekicks, i);
            let right = vector::borrow(&sidekicks, i+1);
            let left_obj = object::address_to_object<Sidekick>(*left);
            let right_obj = object::address_to_object<Sidekick>(*right);
            let left_grade = property_map::read_string(&left_obj, &grade_str);
            assert!(
                left_grade == property_map::read_string(&right_obj, &grade_str),
                error::invalid_argument(EPAIR_HAS_DIFFERENT_GRADE),
            );
            left_grade = to_lower(&mut left_grade);
            let pset = if (left_grade == common_str) {
                vector::borrow(& fusion.probabilities, 0)
            } else if (left_grade == uncommon_str) {
                vector::borrow(&fusion.probabilities, 1)
            } else if (left_grade == rare_str) {
                vector::borrow(&fusion.probabilities, 2)
            } else if (left_grade == epic_str) {
                vector::borrow(&fusion.probabilities, 3)
            } else {
                abort(error::invalid_argument(EFUSION_NOT_SUPPORTED_FOR_GRADE))
            };

            // delete sidekicks
            sidekick::delete_object(package_owner, left_obj);
            sidekick::delete_object(package_owner, right_obj);

            // create new sidekick with the grade-based probability set
            let ref = fuse_sidekick(&creator, pset, left, right, salt, to);
            let object_address = object::address_from_constructor_ref(&ref);
            let obj = object::address_to_object<Sidekick>(object_address);
            orm_object::add_typed_property<Sidekick, String>(
                package_owner, obj, string::utf8(b"@probability_set"),
                gacha_probability::get_id(pset),
            );
            i = i + 2;
        };
    }
}