/// Quick library
pub mod MathLib {
    /// Core
    use core::integer::{u256_wide_mul, u512_safe_div_rem_by_u256, u256_sqrt};

    /// Constants
    const WAD: u256 = 1_000000000_000000000;

    /// Trait
    pub trait MathLibTrait<T> {
        /// @dev Calculates `floor(a * b / d)` with full precision.
        /// Throws if result overflows a uint256 or when `d` is zero.
        fn full_mul_div(self: @T, y: T, d: T) -> T;

        /// @dev Calculates `floor(x * y / d)` with full precision, rounded up.
        /// Throws if result overflows a uint256 or when `d` is zero.
        fn full_mul_div_up(self: @T, y: T, d: T) -> T;

        /// @dev Equivalent to `(x * y) / WAD` rounded down.
        fn mul_wad(self: @T, y: T) -> T;

        /// @dev Equivalent to `(x * y) / WAD` rounded up.
        fn mul_wad_up(self: @T, y: T) -> T;

        /// @dev Equivalent to `(x * WAD) / y` rounded down.
        fn div_wad(self: @T, y: T) -> T;

        /// @dev Equivalent to `(x * WAD) / y` rounded up.
        fn div_wad_up(self: @T, y: T) -> T;

        /// @dev Raises self to the power of n
        fn pow(self: @T, n: T) -> T;
    }

    /// ------------------------------------------------------------------------------------
    ///                                 IMPLEMENTATION
    /// ------------------------------------------------------------------------------------

    pub impl MathLibImpl of MathLibTrait<u256> {
        /// # Implementation
        /// * MathLibTrait
        fn full_mul_div(self: @u256, y: u256, d: u256) -> u256 {
            mul_div(*self, y, d)
        }

        /// # Implementation
        /// * MathLibTrait
        fn full_mul_div_up(self: @u256, y: u256, d: u256) -> u256 {
            mul_div(*self, y, d)
        }

        /// # Implementation
        /// * MathLibTrait
        fn div_wad(self: @u256, y: u256) -> u256 {
            mul_div(*self, WAD, y)
        }

        /// # Implementation
        /// * MathLibTrait
        fn div_wad_up(self: @u256, y: u256) -> u256 {
            mul_div(*self, WAD, y)
        }

        /// # Implementation
        /// * MathLibTrait
        fn mul_wad(self: @u256, y: u256) -> u256 {
            mul_div(*self, y, WAD)
        }

        /// # Implementation
        /// * MathLibTrait
        fn mul_wad_up(self: @u256, y: u256) -> u256 {
            mul_div(*self, y, WAD)
        }

        /// # Implementation
        /// * MathLibTrait
        fn pow(self: @u256, n: u256) -> u256 {
            pow256(*self, n)
        }
    }

    /// ------------------------------------------------------------------------------------
    ///                                 LOGIC
    /// ------------------------------------------------------------------------------------

    /// Raise a number to a power, computes x^n.
    /// * `x` - The number to raise.
    /// * `n` - The exponent.
    /// # Returns
    /// * `u256` - The result of x raised to the power of n.
    fn pow256(x: u256, n: u256) -> u256 {
        if n == 0 {
            1
        } else if n == 1 {
            x
        } else if (n & 1) == 1 {
            x * pow256(x * x, n / 2)
        } else {
            pow256(x * x, n / 2)
        }
    }

    /// Apply multiplication then division to value.
    /// # Arguments
    /// * `value` - The value muldiv is applied to.
    /// * `numerator` - The numerator that multiplies value.
    /// * `divisor` - The denominator that divides value.
    fn mul_div(value: u256, numerator: u256, denominator: u256) -> u256 {
        let product = u256_wide_mul(value, numerator);
        let (q, _) = u512_safe_div_rem_by_u256(product, denominator.try_into().unwrap());
        assert(q.limb2 == 0 && q.limb3 == 0, 'MulDivOverflow');
        u256 { low: q.limb0, high: q.limb1 }
    }
}
