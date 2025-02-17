use core::poseidon::poseidon_hash_span;

trait HashValueTrait<T> {
    fn hash_value(self: @T) -> felt252 {
        poseidon_hash_span(Self::hash_serialize(self))
    }
    fn hash_serialize(self: @T) -> Span<felt252>;
}
