module supervlabs::payment {
    use std::error;
    use std::signer;
    use std::string::String;
    use aptos_std::type_info;
    use aptos_framework::object;
    use aptos_framework::account;
    use aptos_framework::aptos_coin;
    use aptos_framework::chain_id;
    use aptos_framework::event;
    use aptos_framework::aptos_account;
    use aptos_framework::timestamp;
    use apto_orm::orm_creator;
    use apto_orm::proof_challenge;

    #[event]
    struct PackagePurchaseEvent has drop, store {
        user_address: address,
        order_id: String,
        package_id: String,
        package_info: String,
        coin_type: String,
        coin_amount: u64,
    }

    #[event]
    struct PackageRefundEvent has drop, store {
        user_address: address,
        order_id: String,
        package_id: String,
        package_info: String,
        coin_type: String,
        coin_amount: u64,
    }

    struct PaymentAuthorizer has key, drop {
        address: address,
        account_scheme: u8,
        public_key: vector<u8>,
    }

    struct PurchaseVerificationData has drop {
        chain_id: u8,
        user_address: address, 
        user_sequence_number: u64,
        order_id: String,
        order_expiration_date: u64,
        package_id: String,
        package_info: String,
        coin_amount: u64,
    }

    const EORDER_ISSUER_NOT_INITIALIZED: u64 = 1;
    const EORDER_ORDER_EXPIRED: u64 = 2;
    
    const PURCHASE_RECIPIENT: address = @0x38b3da9edcef05e149d0e413c4621b92af981acb0c1932b219bd762433446e49;

    entry fun setup(
        package_owner: &signer,
        issuer_address: address,
        issuer_account_scheme: u8,
        issuer_public_key: vector<u8>
    ) acquires PaymentAuthorizer {
        let orm_creator = object::address_to_object<orm_creator::OrmCreator>(@supervlabs);
        let creator_signer = orm_creator::load_creator(package_owner, orm_creator);
        if (exists<PaymentAuthorizer>(@supervlabs)) {
            let issuer = borrow_global_mut<PaymentAuthorizer>(@supervlabs);
            issuer.public_key = issuer_public_key;
            issuer.account_scheme = issuer_account_scheme;
            issuer.address = issuer_address;
        } else {
            move_to<PaymentAuthorizer>(&creator_signer, PaymentAuthorizer {
                address: issuer_address,
                account_scheme: issuer_account_scheme,
                public_key: issuer_public_key,
            });
        }
    }

    entry fun purchase(
        user : &signer,
        order_id: String,
        order_expiration_date: u64,
        package_id: String,
        package_info: String,
        coin_amount: u64,
        order_proof: vector<u8>,
    ) acquires PaymentAuthorizer {
        assert!(
            exists<PaymentAuthorizer>(@supervlabs),
            error::invalid_state(EORDER_ISSUER_NOT_INITIALIZED)
        );
        let issuer = borrow_global_mut<PaymentAuthorizer>(@supervlabs);
        let user_address = signer::address_of(user);
        proof_challenge::verify<PurchaseVerificationData>(
            user,
            PurchaseVerificationData {
                chain_id: chain_id::get(),
                user_address,
                user_sequence_number: account::get_sequence_number(user_address),
                order_expiration_date,
                order_id,
                package_id,
                package_info,
                coin_amount,
            },
            issuer.address,
            issuer.account_scheme,
            issuer.public_key,
            order_proof,
            false,
        );
        assert!(
            order_expiration_date == 0 ||
            order_expiration_date >= timestamp::now_seconds(),
            error::invalid_state(EORDER_ORDER_EXPIRED)
        );
        event::emit(PackagePurchaseEvent {
            user_address,
            order_id,
            package_id,
            package_info,
            coin_type: type_info::type_name<aptos_coin::AptosCoin>(),
            coin_amount,
        });
        aptos_account::transfer(user, PURCHASE_RECIPIENT, coin_amount);
    }

    entry fun refund(
        refunder : &signer,
        user : address,
        order_id: String,
        package_id: String,
        package_info: String,
        coin_amount: u64,
    ) {
        event::emit(PackageRefundEvent {
            user_address: user,
            order_id,
            package_id,
            package_info,
            coin_type: type_info::type_name<aptos_coin::AptosCoin>(),
            coin_amount,
        });
        aptos_account::transfer(refunder, user, coin_amount);
    }
}