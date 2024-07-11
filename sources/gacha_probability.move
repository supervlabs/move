/// This module provides the preset of the probabilities used in Supervlabs Gacha system.
/// All probabilities and graded are stored as a string for readability and they are loaded 
/// as fractional numbers by `get_probabilities` function in Supervlabs Gacha system.
module supervlabs::gacha_probability {
    use std::vector;
    use std::string::String;
    use apto_orm::utilities;

    // e.g. grade: rare, probability: 0.2
    struct GachaProbability has copy, drop, store {
        grade: String,
        probability: String,
    }

    struct GachaProbabilitySet has copy, drop, store {
        id : String,
        list: vector<GachaProbability>,
    }

    public fun new(
        id: String,
        grades: vector<String>,
        probabilities: vector<String>,
    ): GachaProbabilitySet {
        let list: vector<GachaProbability> = vector[];
        vector::enumerate_ref(&grades, |i, grade| {
            let probability = *vector::borrow(&probabilities, i);
            vector::push_back(&mut list, GachaProbability { grade: *grade, probability });
        });
        GachaProbabilitySet { id, list }
    }

    public fun add(probabilities: &mut GachaProbabilitySet, grade: String, probability: String) {
        vector::push_back(&mut probabilities.list, GachaProbability { grade, probability });
    }

    public fun replace(probabilities: &mut GachaProbabilitySet, i: u64, grade: String, probability: String) {
        vector::insert(&mut probabilities.list, i, GachaProbability { grade, probability });
    }

    // return a list of probabilities (numerators based on the input denominator)
    public fun get_probabilities(probabilities: &GachaProbabilitySet, denominator: u64): (vector<String>, vector<u64>) {
        let grades: vector<String> = vector[];
        let numerators: vector<u64> = vector[];
        vector::for_each_ref(&probabilities.list, |e| {
            let p: &GachaProbability = e;
            let (grade_numerator, grade_denominator) = utilities::str_to_rational_number(&p.probability);
            let numerator = denominator / grade_denominator * grade_numerator;
            vector::push_back(&mut grades, p.grade);
            vector::push_back(&mut numerators, numerator);
        });
        (grades, numerators)
    }

    public fun get_id(probabilities: &GachaProbabilitySet): String {
        probabilities.id
    }

    #[test]
    public fun test_probabilities() {
        use std::string;
        let probabilities = new(
            string::utf8(b"probabilities"),
            vector[
                string::utf8(b"rare"),
                string::utf8(b"epic"),
                string::utf8(b"legendary"),
                string::utf8(b"mythic"),
            ],
            vector[
                string::utf8(b"0.3"),
                string::utf8(b"0.2"),
                string::utf8(b"0.1"),
                string::utf8(b"0.001"),
            ]);
        let (grades, numerators) = get_probabilities(&probabilities, 1000);
        vector::enumerate_ref(&grades, |i, grade| {
            let probability = *vector::borrow(&numerators, i);
            if (i == 0) {
                assert!(probability == 300, 0x10);
                assert!(*grade == string::utf8(b"rare"), 0x11);
            } else if (i == 1) {
                assert!(probability == 200, 0x10);
                assert!(*grade == string::utf8(b"epic"), 0x11);
            } else if (i == 2) {
                assert!(probability == 100, 0x10);
                assert!(*grade == string::utf8(b"legendary"), 0x11);
            } else if (i == 3) {
                assert!(probability == 1, 0x10);
                assert!(*grade == string::utf8(b"mythic"), 0x11);
            };
        });
    }
}