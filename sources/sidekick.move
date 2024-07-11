module supervlabs::sidekick {
    use apto_orm::orm_class;
    use apto_orm::orm_creator;
    use apto_orm::orm_module;
    use apto_orm::orm_object;
    use aptos_framework::object::{Self, Object, ConstructorRef};
    use aptos_framework::timestamp;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    use aptos_framework::randomness;

    use supervlabs::gacha_rounds;
    use supervlabs::gacha_item;
    use supervlabs::sidekick_capsule;
    use supervlabs::random;
    use supervlabs::gacha_supply;

    const CLASS_NAME: vector<u8> = b"Sidekick";
    const ENOT_SIDEKICK_OBJECT: u64 = 4;
    const EINVALID_AMOUNT: u64 = 5;
    const EUNABLE_TO_MINT_TARGET_SIDEKICK_DUE_TO_LIMITED_SUPPLY: u64 = 6;
    const EDEPRECATED_FUNCTION: u64 = 10;

    const SIDEKICK_DRAW_SUPPLY_INDEX: u64 = 0;

    friend supervlabs::sidekick_fusion;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Sidekick has key, drop {
        updated_at: u64,
        salt: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct SidekickMintRequest has key, drop {
        request_id: String,
    }

    fun init_module(package: &signer) {
        let class_address = orm_class::update_class_as_collection<Sidekick>(
            package,
            string::utf8(b"SuperV Sidekicks"),
            true, true, false, true, false, true, false,
            string::utf8(b"https://public.vir.supervlabs.io/virweb/nft/sidekicks/collection.png"),
            string::utf8(b"Sidekicks, as faithful allies of the Villains, stand by their side and help maximize the Villains' potential. They typically inhabit the wild before being captured by Villains. By establishing a deep connection, they are reborn as true Sidekicks."),
            0,
            true,
            true,
            @0x0,
            100,
            5,
        );
        orm_module::set<Sidekick>(
            package,
            signer::address_of(package),
            class_address,
        );
        let pa = signer::address_of(package);
        let orm_class_obj = object::address_to_object<orm_class::OrmClass>(class_address);
        if (!gacha_rounds::exists_at(class_address)) {
            let class_signer = orm_class::load_class_signer(package, orm_class_obj);
            let grades = vector[
                string::utf8(b"legendary"),
                string::utf8(b"epic"),
                string::utf8(b"rare"),
                string::utf8(b"uncommon"),
            ];
            gacha_rounds::add(&class_signer, pa, grades, vector[
                100000, 800000, 5000000, 30000000], 100000000); // 0.1%, 0.8%, 5%, 30%, etc.
        };

        if (!gacha_supply::exists_at(class_address) && orm_class::has_class_signer(orm_class_obj)) {
            let class_signer = orm_class::load_class_signer(package, orm_class_obj);
            let (current_round, _, _, _) = gacha_rounds::get_probabilities(class_address);
            gacha_supply::init(&class_signer, vector[
                // SIDEKICK_DRAW_SUPPLY_INDEX = 0
                gacha_supply::new_supply(
                    string::utf8(b"legendary_sidekick_draw"),
                    string::utf8(b"legendary"), 0, 1000, current_round),
            ]);
        };
    }

    entry fun update_module(package_owner: &signer) {
        let (orm_creator, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let package = orm_creator::load_creator(package_owner, orm_creator);
        init_module(&package);
        let class_address = object::object_address(&orm_class);
        gacha_rounds::update_probabilities(&package, class_address, 0,
            vector[
                string::utf8(b"legendary"),
                string::utf8(b"epic"),
                string::utf8(b"rare"),
                string::utf8(b"uncommon"),
            ],
            vector[100000, 800000, 5000000, 30000000],
            100000000
        );
    }

    public(friend) fun create_object(
        creator_signer: &signer,
        _input_address: address,
        salt: u64,
        to: Option<address>,
        grades: vector<String>,
        numerators: vector<u64>,
        denominator: u64,
    ): (ConstructorRef, bool) {
        let (_, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let class_address = object::object_address(&orm_class);
        let supply = gacha_supply::get(class_address, SIDEKICK_DRAW_SUPPLY_INDEX);
        if (gacha_supply::check_run_out(&supply)) {
            let index = gacha_supply::get_add_info(&supply);
            let numerator = vector::borrow_mut(&mut numerators, index);
            *numerator = 0;
        };

        let roll1 = randomness::u64_range(0, denominator);
        let round_up = false;
        let (group, start_index, end_index) = (string::utf8(b""), 0, 0);
        let i = 0;
        let upto = 0;
        let len = vector::length(&grades);
        while (i < len) {
            let grade = vector::borrow(&grades, i);
            let numerator = vector::borrow(&numerators, i);
            upto = upto + *numerator;
            if (roll1 < upto) {
                let key = string::utf8(b"sidekick/");
                string::append(&mut key, *grade);
                (group, start_index, end_index, _) = gacha_item::get_item_group(key);
                if (i == gacha_supply::get_add_info(&supply)) round_up = true;
                break
            };
            i = i + 1;
        };
        if (i == len) {
            let key = string::utf8(b"sidekick/common");
            (group, start_index, end_index, _) = gacha_item::get_item_group(key);
        };

        let roll2 = randomness::u64_range(start_index, end_index);
        let (name, uri, description, _, property_keys, property_types, property_values)
            = gacha_item::load_item_data(creator_signer, group, roll2);
        let ref = token::create(
            creator_signer,
            string::utf8(b"SuperV Sidekicks"),
            description,
            name, // format: "{ItemName} #{count}"
            option::none(),
            uri,
        );
        let object_signer = orm_object::init<Sidekick>(creator_signer, &ref, orm_class);

        orm_object::init_properties(&ref,
            property_keys,
            property_types,
            property_values,
        );

        let updated_at = timestamp::now_seconds();
        move_to<Sidekick>(&object_signer, Sidekick {
            updated_at: updated_at, salt: salt
        });

        random::store_roll_u64(&object_signer, roll1, 0, denominator);
        random::store_roll_u64(&object_signer, roll2, start_index, end_index);

        if (option::is_some(&to)) {
            let destination = option::extract<address>(&mut to);
            orm_object::transfer_initially(&ref, destination);
        };

        if (round_up) {
            gacha_supply::increase(class_address, SIDEKICK_DRAW_SUPPLY_INDEX, 1);
        };
        (ref, round_up)
    }

    fun update_object<T: key>(
        package_owner: &signer,
        object: Object<T>,
    ) acquires Sidekick {
        let object_address = object::object_address(&object);
        assert!(
            exists<Sidekick>(object_address),
            error::invalid_argument(ENOT_SIDEKICK_OBJECT),
        );
        let _object_signer = orm_object::load_signer(package_owner, object);
        let user_data = borrow_global_mut<Sidekick>(object_address);
        user_data.updated_at = timestamp::now_seconds();
    }

    public fun delete_object<T: key>(
        package_owner: &signer,
        object: Object<T>,
    ) acquires Sidekick {
        let object_address = object::object_address(&object);
        assert!(
          exists<Sidekick>(object_address),
          error::invalid_argument(ENOT_SIDEKICK_OBJECT),
        );
        move_from<Sidekick>(object_address);
        orm_object::remove(package_owner, object);
    }

    #[randomness]
    entry fun create(
        package_owner: &signer,
        sidekick_capsule: address,
        salt: u64,
    ) {
        // burn sidekick_capsule
        if (sidekick_capsule != @0x0) {
            let sidekick_capsule_obj = object::address_to_object<sidekick_capsule::SidekickCapsule>(sidekick_capsule);
            sidekick_capsule::delete_object(package_owner, sidekick_capsule_obj);
        };
        let (orm_creator, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let class_address = object::object_address(&orm_class);
        let creator_signer = orm_creator::load_creator(package_owner, orm_creator);
        let (current_round, grades, numerators, denominator) = gacha_rounds::get_probabilities(class_address);

        let (ref, round_up) = create_object(
            &creator_signer, sidekick_capsule, salt, option::none(),
            grades, numerators, denominator,
        );
        gacha_rounds::set_round_log(class_address, &ref, current_round);
        if (round_up) {
            gacha_rounds::round_up(&creator_signer, class_address);
        };
    }

    #[randomness]
    entry fun create_to(
        package_owner: &signer,
        sidekick_capsule: address,
        salt: u64,
        to: address,
    ) {
        // burn sidekick_capsule
        if (sidekick_capsule != @0x0) {
            let sidekick_capsule_obj = object::address_to_object<sidekick_capsule::SidekickCapsule>(sidekick_capsule);
            sidekick_capsule::delete_object(package_owner, sidekick_capsule_obj);
        };
        let (orm_creator, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let class_address = object::object_address(&orm_class);
        let creator_signer = orm_creator::load_creator(package_owner, orm_creator);
        let (current_round, grades, numerators, denominator) = gacha_rounds::get_probabilities(class_address);

        let (ref, round_up) = create_object(
            &creator_signer, sidekick_capsule, salt, option::some(to),
            grades, numerators, denominator,
        );
        gacha_rounds::set_round_log(class_address, &ref, current_round);
        if (round_up) {
            gacha_rounds::round_up(&creator_signer, class_address);
        };
    }

    fun draw_sidekicks_internal(
        package_owner: &signer,
        sidekick_capsules: vector<address>,
        salt: u64,
        amount: u64,
        to: address,
    ): vector<ConstructorRef> {
        assert!(amount > 0, error::invalid_argument(EINVALID_AMOUNT));
        let calsules_len = vector::length(&sidekick_capsules);
        if (calsules_len > 0) {
            assert!(amount == calsules_len, error::invalid_argument(EINVALID_AMOUNT));
        };
        // burn all sidekick_capsules
        vector::for_each_ref(&sidekick_capsules, |sidekick_capsule| {
            if (*sidekick_capsule != @0x0) {
                let sidekick_capsule_obj =
                    object::address_to_object<sidekick_capsule::SidekickCapsule>(*sidekick_capsule);
                sidekick_capsule::delete_object(package_owner, sidekick_capsule_obj);
            };
        });

        let (orm_creator, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let class_address = object::object_address(&orm_class);
        let creator_signer = orm_creator::load_creator(package_owner, orm_creator);

        let current_round: u64 = 0;
        let grades: vector<String> = vector::empty();
        let numerators: vector<u64> = vector::empty();
        let denominator: u64 = 100000000;
        let load_prob: bool = true;
        let i = 0;
        let r: vector<ConstructorRef> = vector::empty();
        while (i < amount) {
            if (load_prob) {
                (current_round, grades, numerators, denominator)
                    = gacha_rounds::get_probabilities(class_address);
                load_prob = false;
            };
            let (ref, round_up) = create_object(
                &creator_signer, to, salt + i, option::some(to),
                grades, numerators, denominator,
            );
            gacha_rounds::set_round_log(class_address, &ref, current_round);
            if (round_up) {
                gacha_rounds::round_up(&creator_signer, class_address);
                load_prob = true;
            };
            i = i+1;
            vector::push_back(&mut r, ref);
        };
        r
    }

    #[randomness]
    entry fun draw_sidekicks(
        package_owner: &signer,
        sidekick_capsules: vector<address>,
        salt: u64,
        amount: u64,
        to: address,
    ) {
        draw_sidekicks_internal(package_owner, sidekick_capsules, salt, amount, to);
    }

    entry fun update(
        package_owner: &signer,
        object: address,
    ) acquires Sidekick {
        let obj = object::address_to_object<Sidekick>(object);
        update_object(package_owner, obj);
    }

    entry fun delete(
        package_owner: &signer,
        object: address,
    ) acquires Sidekick {
        let obj = object::address_to_object<Sidekick>(object);
        delete_object(package_owner, obj);
    }

    #[view]
    public fun get(object: address): (
        string::String,
        string::String,
        string::String,
        address,
        u64,
        u64,
    ) acquires Sidekick {
        let o = object::address_to_object<Sidekick>(object);
        let user_data = borrow_global<Sidekick>(object);
        (
            token::name(o),
            token::uri(o),
            token::description(o),
            property_map::read_address(&o, &string::utf8(b"sidekick_capsule")),
            user_data.updated_at,
            user_data.salt,
        )
    }

    #[view]
    public fun exists_at(object: address): bool {
        exists<Sidekick>(object)
    }

    #[view]
    public fun replay_to_create_object(_object: address): (
        string::String, u64, u64, u64, u64, u64, u64, u64, u64, string::String, u64, u64,
    ) {
        abort(error::invalid_argument(EDEPRECATED_FUNCTION))
    }

    #[test_only]
    fun update_limited_supply(package: &signer, max: u64, max_from_game: u64) {
        let (_, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let class_address = object::object_address(&orm_class);
        let class_signer = orm_class::load_class_signer(package, orm_class);
        let (current_round, _, _, _) = gacha_rounds::get_probabilities(class_address);
        gacha_supply::init(&class_signer, vector[
            // SIDEKICK_DRAW_SUPPLY_INDEX = 0
            gacha_supply::new_supply(string::utf8(b"legendary_sidekick_draw"), string::utf8(b"legendary"), 0, max, current_round),
            // SIDEKICK_FROM_GAME_SUPPLY_INDEX = 1
            gacha_supply::new_supply(string::utf8(b"legendary_sidekick_from_game"), string::utf8(b"legendary"), 0, max_from_game, 0),
        ]);
    }


    #[test(aptos = @0x1, my_poa = @0x456, user1 = @0x789, user2 = @0xabc, apto_orm = @apto_orm, creator = @package_creator)]
    // #[expected_failure(abort_code = 196614, location = Self)] // EUNABLE_TO_MINT_TARGET_SIDEKICK_DUE_TO_LIMITED_SUPPLY
    public entry fun test_sidekick_limited_supply(
        aptos: &signer, apto_orm: &signer, creator: &signer, my_poa: &signer, user1: &signer, user2: &signer
    ) {
        use apto_orm::test_utilities;
        use apto_orm::power_of_attorney;
        use aptos_std::debug;
        test_utilities::init_network(aptos, 1234);
        randomness::initialize_for_testing(aptos);

        let program_address = signer::address_of(apto_orm);
        let creator_address = signer::address_of(creator);
        let my_poa_address = signer::address_of(my_poa);
        let user1_address = signer::address_of(user1);
        let user2_address = signer::address_of(user2);

        test_utilities::create_and_fund_account(program_address, 100);
        test_utilities::create_and_fund_account(creator_address, 10);
        test_utilities::create_and_fund_account(my_poa_address, 100);
        test_utilities::create_and_fund_account(user1_address, 100);
        test_utilities::create_and_fund_account(user2_address, 10);
        let package = orm_creator::create_creator(creator, string::utf8(b"supervlabs"));

        let target_supply = 2;
        init_module(&package);
        update_limited_supply(&package, target_supply, target_supply);

        gacha_item::test_init_module(creator, &package);
        power_of_attorney::register_poa(creator, my_poa, 1400, 0);
        let refs = draw_sidekicks_internal(my_poa, vector::empty(), 1, 5000, user1_address);
        let len = vector::length(&refs);
        let i = 0;
        while (i < len) {
            let ref = vector::borrow(&refs, i);
            let obj = object::object_from_constructor_ref<Sidekick>(ref);
            assert!(object::owner(obj) == user1_address, 1);
            i = i + 1;
        };
        let (_, orm_class) = orm_module::get<Sidekick>(@supervlabs);
        let class_address = object::object_address(&orm_class);
        let supply = gacha_supply::get(class_address, SIDEKICK_DRAW_SUPPLY_INDEX);
        debug::print<gacha_supply::SupplyInfo>(&supply);
        assert!(gacha_supply::check_run_out(&supply), 1);
    }
}