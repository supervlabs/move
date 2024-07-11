module supervlabs::costume {
    use apto_orm::orm_class;
    use apto_orm::orm_creator;
    use apto_orm::orm_module;
    use apto_orm::orm_object;
    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use std::bcs;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::string;

    const CLASS_NAME: vector<u8> = b"Costume";
    const ECOSTUME_OBJECT_NOT_FOUND: u64 = 1;
    const ENOT_COSTUME_OBJECT: u64 = 2;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Costume has key, drop {
    }

    fun init_module(package: &signer) {
        let class_address = orm_class::update_class_as_collection<Costume>(
            package,
            string::utf8(b"SuperV Costumes"),
            true, true, false, true, false, true, false,
            string::utf8(b"https://public.vir.supervlabs.io/virweb/nft/costumes/collection.png"),
            string::utf8(b"Costumes complete players: they not only alter their appearance but also bestow mysterious powers."),
            0,
            true,
            true,
            @0x0,
            100,
            5,
        );
        orm_module::set<Costume>(
            package,
            signer::address_of(package),
            class_address,
        );
    }

    entry fun update_module(user: &signer) {
        let (orm_creator, _) = orm_module::get<Costume>(@supervlabs);
        let package = orm_creator::load_creator(user, orm_creator);
        init_module(&package);
    }

    fun create_object(
        user: &signer,
        name: string::String,
        uri: string::String,
        description: string::String,
        grade: string::String,
        category: string::String,
        to: Option<address>,
    ): Object<Costume>{
        let (orm_creator, orm_class) = orm_module::get<Costume>(@supervlabs);
        let creator_signer = orm_creator::load_creator(user, orm_creator);
        let ref = token::create(
            &creator_signer,
            string::utf8(b"SuperV Costumes"),
            description,
            name,
            option::none(),
            uri,
        );
        orm_object::init_properties(&ref,
            vector[
                string::utf8(b"grade"),
                string::utf8(b"category"),
            ],
            vector[
                string::utf8(b"0x1::string::String"),
                string::utf8(b"0x1::string::String"),
            ],
            vector[
                bcs::to_bytes<0x1::string::String>(&grade),
                bcs::to_bytes<0x1::string::String>(&category),
            ],
        );
        let object_signer = orm_object::init<Costume>(&creator_signer, &ref, orm_class);
        move_to<Costume>(&object_signer, Costume {
        });
        if (option::is_some(&to)) {
            let destination = option::extract<address>(&mut to);
            orm_object::transfer_initially(&ref, destination);
        };
        object::object_from_constructor_ref<Costume>(&ref)
    }

    fun update_object<T: key>(
        user: &signer,
        object: Object<T>,
        name: string::String,
        uri: string::String,
        description: string::String,
        grade: string::String,
        category: string::String,
    ) {
        let object_address = object::object_address(&object);
        assert!(
            exists<Costume>(object_address),
            error::invalid_argument(ENOT_COSTUME_OBJECT),
        );
        let object_signer = orm_object::load_signer(user, object);
        orm_object::add_typed_property<T, 0x1::string::String>(
            &object_signer, object, string::utf8(b"grade"), grade,
        );
        orm_object::add_typed_property<T, 0x1::string::String>(
            &object_signer, object, string::utf8(b"category"), category,
        );
        orm_object::set_name(user, object, name);
        orm_object::set_uri(user, object, uri);
        orm_object::set_description(user, object, description);
    }

    fun delete_object<T: key>(
        user: &signer,
        object: Object<T>,
    ) acquires Costume {
        let object_address = object::object_address(&object);
        assert!(
          exists<Costume>(object_address),
          error::invalid_argument(ENOT_COSTUME_OBJECT),
        );
        move_from<Costume>(object_address);
        orm_object::remove(user, object);
    }

    entry fun create(
        user: &signer,
        name: string::String,
        uri: string::String,
        description: string::String,
        grade: string::String,
        category: string::String,
    ) {
        create_object(user, name, uri, description, grade, category, option::none());
    }

    entry fun create_to(
        user: &signer,
        name: string::String,
        uri: string::String,
        description: string::String,
        grade: string::String,
        category: string::String,
        to: address,
    ) {
        create_object(user, name, uri, description, grade, category, option::some(to));
    }

    entry fun update(
        user: &signer,
        object: address,
        name: string::String,
        uri: string::String,
        description: string::String,
        grade: string::String,
        category: string::String,
    ) {
        let obj = object::address_to_object<Costume>(object);
        update_object(user, obj, name, uri, description, grade, category);
    }

    entry fun delete(
        user: &signer,
        object: address,
    ) acquires Costume {
        let obj = object::address_to_object<Costume>(object);
        delete_object(user, obj);
    }

    #[view]
    public fun get(object: address): (
        string::String,
        string::String,
        string::String,
        string::String,
        string::String,
    )  {
        let o = object::address_to_object<Costume>(object);
        (
            token::name(o),
            token::uri(o),
            token::description(o),
            property_map::read_string(&o, &string::utf8(b"grade")),
            property_map::read_string(&o, &string::utf8(b"category")),
        )
    }

    #[view]
    public fun exists_at(object: address): bool {
        exists<Costume>(object)
    }
}