pragma solidity ^0.6.0;

import "./SafeMath.sol";

/**
 * @title Reduces the size of terms before multiplication, to avoid an overflow, and then
 * restores the proper size after division.
 * @notice This effectively allows us to overflow values in the numerator and/or denominator
 * of a fraction, so long as the end result does not overflow as well.
 * @dev Results may be off by 1 + 0.000001% for 2x1 calls and 2 + 0.00001% for 2x2 calls.
 * Do not use if your contract expects very small result values to be accurate.
 */
library BigDiv {
    using SafeMath for uint256;

    /// @notice The max possible value
    uint256 private constant MAX_UINT = 2**256 - 1;

    /// @notice When multiplying 2 terms <= this value the result won't overflow
    uint256 private constant MAX_BEFORE_SQUARE = 2**128 - 1;

    /// @notice The max error target is off by 1 plus up to 0.000001% error
    /// for bigDiv2x1 and that `* 2` for bigDiv2x2
    uint256 private constant MAX_ERROR = 100000000;

    /// @notice A larger error threshold to use when multiple rounding errors may apply
    uint256 private constant MAX_ERROR_BEFORE_DIV = MAX_ERROR * 2;

    /**
     * @notice Returns the approx result of `a * b / d` so long as the result is <= MAX_UINT
     * @param _numA the first numerator term
     * @param _numB the second numerator term
     * @param _den the denominator
     * @return the approx result with up to off by 1 + MAX_ERROR, rounding down if needed
     */
    function bigDiv2x1(
        uint256 _numA,
        uint256 _numB,
        uint256 _den
    ) internal pure returns (uint256) {
        if (_numA == 0 || _numB == 0) {
            // would div by 0 or underflow if we don't special case 0
            return 0;
        }

        uint256 value;

        if (MAX_UINT / _numA >= _numB) {
            // a*b does not overflow, return exact math
            value = _numA * _numB;
            value /= _den;
            return value;
        }

        // Sort numerators
        uint256 numMax = _numB;
        uint256 numMin = _numA;
        if (_numA > _numB) {
            numMax = _numA;
            numMin = _numB;
        }

        value = numMax / _den;
        if (value > MAX_ERROR) {
            // _den is small enough to be MAX_ERROR or better w/o a factor
            value = value.mul(numMin);
            return value;
        }

        // formula = ((a / f) * b) / (d / f)
        // factor >= a / sqrt(MAX) * (b / sqrt(MAX))
        uint256 factor = numMin - 1;
        factor /= MAX_BEFORE_SQUARE;
        factor += 1;
        uint256 temp = numMax - 1;
        temp /= MAX_BEFORE_SQUARE;
        temp += 1;
        if (MAX_UINT / factor >= temp) {
            factor *= temp;
            value = numMax / factor;
            if (value > MAX_ERROR_BEFORE_DIV) {
                value = value.mul(numMin);
                temp = _den - 1;
                temp /= factor;
                temp = temp.add(1);
                value /= temp;
                return value;
            }
        }

        // formula: (a / (d / f)) * (b / f)
        // factor: b / sqrt(MAX)
        factor = numMin - 1;
        factor /= MAX_BEFORE_SQUARE;
        factor += 1;
        value = numMin / factor;
        temp = _den - 1;
        temp /= factor;
        temp += 1;
        temp = numMax / temp;
        value = value.mul(temp);
        return value;
    }
}