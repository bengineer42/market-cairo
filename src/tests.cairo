use core::poseidon::poseidon_hash_span;
use dojo::utils::bytearray_hash;
use market::direct::components::{DIRECT_NAMESPACE_HASH, DIRECT_SINGLE_SELECTOR};

#[test]
fn test_selector() {
    println!("0x{DIRECT_NAMESPACE_HASH:x}");
    println!("0x{DIRECT_SINGLE_SELECTOR:x}");
    let selector = poseidon_hash_span(
        [bytearray_hash(@"direct_market"), bytearray_hash(@"DirectSingle")].span(),
    );
    println!("0x{selector:x}");
}
