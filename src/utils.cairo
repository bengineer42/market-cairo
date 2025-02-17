use core::num::traits::WideMul;
use core::integer::u512_safe_div_rem_by_u256;

fn calc_tax(amount: u256, tax_ppm: u32) -> u256 {
    let (val, _) = u512_safe_div_rem_by_u256(amount.wide_mul(tax_ppm.into()), 1_000_000);
    val.try_into().unwrap()
}

