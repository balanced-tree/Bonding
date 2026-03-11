// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Types
import "../src/Types.sol" as Types;

abstract contract Helpers {

    /*//////////////////////////////////////////////////////////////
                          LINEAR SEGMENT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Default linear: p(s) = 1*s + 0  (slope=1, intercept=0)
    function _createLinearSegment(
      uint256 supplyStart,
      uint256 supplyEnd
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return _createLinearSegment(supplyStart, supplyEnd, 1e18, 0);
    }

    function _createLinearSegment(
      uint256 supplyStart,
      uint256 supplyEnd,
      int256 m,
      int256 b
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return Types.PiecewiseSegment({
            supplyStart: supplyStart,
            supplyEnd: supplyEnd,
            formulaType: Types.FormulaType.LINEAR,
            encodedParams: abi.encode(Types.LinearParams({
                m: m,
                b: b
            }))
        });
    }

    /*//////////////////////////////////////////////////////////////
                          LN SEGMENT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Default ln: p(s) = 1*ln(s + 1) + 0  (a=1, b=0, c=1)
    ///      c=1 ensures domain validity at s=0
    function _createLnSegment(
      uint256 supplyStart,
      uint256 supplyEnd
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return _createLnSegment(supplyStart, supplyEnd, 1e18, 0, 1e18);
    }

    function _createLnSegment(
      uint256 supplyStart,
      uint256 supplyEnd,
      int256 a,
      int256 b,
      int256 c
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return Types.PiecewiseSegment({
            supplyStart: supplyStart,
            supplyEnd: supplyEnd,
            formulaType: Types.FormulaType.LN,
            encodedParams: abi.encode(Types.LnParams({
                a: a,
                b: b,
                c: c
            }))
        });
    }

    /*//////////////////////////////////////////////////////////////
                          SIN SEGMENT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Default sin: p(s) = 1*sin(1*s + 0) + 2  (a=1, w=1, phi=0, b=2)
    ///      b=2 keeps price positive since amplitude is 1
    function _createSinSegment(
      uint256 supplyStart,
      uint256 supplyEnd
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return _createSinSegment(supplyStart, supplyEnd, 1e18, 1e18, 0, 2e18);
    }

    function _createSinSegment(
      uint256 supplyStart,
      uint256 supplyEnd,
      int256 a,
      int256 w,
      int256 phi,
      int256 b
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return Types.PiecewiseSegment({
            supplyStart: supplyStart,
            supplyEnd: supplyEnd,
            formulaType: Types.FormulaType.SIN,
            encodedParams: abi.encode(Types.SinParams({
                a: a,
                w: w,
                phi: phi,
                b: b
            }))
        });
    }

    /*//////////////////////////////////////////////////////////////
                          PARABOLIC SEGMENT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Default parabolic: p(s) = 1*s² + 0*s + 0  (a=1, b=0, c=0)
    function _createParabolicSegment(
      uint256 supplyStart,
      uint256 supplyEnd
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return _createParabolicSegment(supplyStart, supplyEnd, 1e18, 0, 0);
    }

    function _createParabolicSegment(
      uint256 supplyStart,
      uint256 supplyEnd,
      int256 a,
      int256 b,
      int256 c
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return Types.PiecewiseSegment({
            supplyStart: supplyStart,
            supplyEnd: supplyEnd,
            formulaType: Types.FormulaType.PARABOLIC,
            encodedParams: abi.encode(Types.ParabolicParams({
                a: a,
                b: b,
                c: c
            }))
        });
    }

    /*//////////////////////////////////////////////////////////////
                          EXPONENTIAL SEGMENT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Default exponential: p(s) = 1*e^(1*s) + 0  (a=1, k=1, b=0)
    function _createExponentialSegment(
      uint256 supplyStart,
      uint256 supplyEnd
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return _createExponentialSegment(supplyStart, supplyEnd, 1e18, 1e18, 0);
    }

    function _createExponentialSegment(
      uint256 supplyStart,
      uint256 supplyEnd,
      int256 a,
      int256 k,
      int256 b
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return Types.PiecewiseSegment({
            supplyStart: supplyStart,
            supplyEnd: supplyEnd,
            formulaType: Types.FormulaType.EXPONENTIAL,
            encodedParams: abi.encode(Types.ExponentialParams({
                a: a,
                k: k,
                b: b
            }))
        });
    }

    /*//////////////////////////////////////////////////////////////
                          SIGMOID SEGMENT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Default sigmoid: p(s) = 10/(1+e^(-1*(s-5))) + 0
    ///      maxVal=10, k=1, s0=5 (midpoint at supply=5), b=0
    function _createSigmoidSegment(
      uint256 supplyStart,
      uint256 supplyEnd
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return _createSigmoidSegment(supplyStart, supplyEnd, 10e18, 1e18, 5e18, 0);
    }

    function _createSigmoidSegment(
      uint256 supplyStart,
      uint256 supplyEnd,
      int256 maxVal,
      int256 k,
      int256 s0,
      int256 b
    ) internal pure returns (Types.PiecewiseSegment memory) {
        return Types.PiecewiseSegment({
            supplyStart: supplyStart,
            supplyEnd: supplyEnd,
            formulaType: Types.FormulaType.SIGMOID,
            encodedParams: abi.encode(Types.SigmoidParams({
                maxVal: maxVal,
                k: k,
                s0: s0,
                b: b
            }))
        });
    }

    /*//////////////////////////////////////////////////////////////
                          MULTI-SEGMENT ARRAY BUILDERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Build a segment array from formula types + matching start/end pairs.
    ///      Uses default (realistic) params for each formula type.
    ///      `starts` and `ends` must have the same length as `formulaTypes`.
    function _createSegments(
        Types.FormulaType[] memory formulaTypes,
        uint256[] memory starts,
        uint256[] memory ends
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        require(formulaTypes.length == starts.length && starts.length == ends.length, "length mismatch");
        segments = new Types.PiecewiseSegment[](formulaTypes.length);
        for (uint256 i = 0; i < formulaTypes.length; i++) {
            segments[i] = _createDefaultSegment(formulaTypes[i], starts[i], ends[i]);
        }
    }

    /// @dev Dispatches to the default-param helper for the given formula type.
    function _createDefaultSegment(
        Types.FormulaType formulaType,
        uint256 supplyStart,
        uint256 supplyEnd
    ) internal pure returns (Types.PiecewiseSegment memory) {
        if (formulaType == Types.FormulaType.LINEAR) return _createLinearSegment(supplyStart, supplyEnd);
        if (formulaType == Types.FormulaType.LN) return _createLnSegment(supplyStart, supplyEnd);
        if (formulaType == Types.FormulaType.SIN) return _createSinSegment(supplyStart, supplyEnd);
        if (formulaType == Types.FormulaType.PARABOLIC) return _createParabolicSegment(supplyStart, supplyEnd);
        if (formulaType == Types.FormulaType.EXPONENTIAL) return _createExponentialSegment(supplyStart, supplyEnd);
        if (formulaType == Types.FormulaType.SIGMOID) return _createSigmoidSegment(supplyStart, supplyEnd);
        revert("unknown formula type");
    }

    /*//////////////////////////////////////////////////////////////
                        PRESET MULTI-SEGMENT COMBINATIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Two-segment curve: LINEAR then LINEAR (e.g. different slopes per phase)
    function _createLinearLinearSegments(
        uint256 boundary
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        segments = new Types.PiecewiseSegment[](2);
        segments[0] = _createLinearSegment(0, boundary);
        segments[1] = _createLinearSegment(boundary, boundary * 2);
    }

    /// @dev Two-segment curve: LINEAR then LN (common: cheap start → logarithmic growth)
    function _createLinearLnSegments(
        uint256 boundary
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        segments = new Types.PiecewiseSegment[](2);
        segments[0] = _createLinearSegment(0, boundary);
        segments[1] = _createLnSegment(boundary, boundary * 2);
    }

    /// @dev Two-segment curve: LINEAR then EXPONENTIAL
    function _createLinearExponentialSegments(
        uint256 boundary
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        segments = new Types.PiecewiseSegment[](2);
        segments[0] = _createLinearSegment(0, boundary);
        segments[1] = _createExponentialSegment(boundary, boundary * 2);
    }

    /// @dev Two-segment curve: LINEAR then PARABOLIC
    function _createLinearParabolicSegments(
        uint256 boundary
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        segments = new Types.PiecewiseSegment[](2);
        segments[0] = _createLinearSegment(0, boundary);
        segments[1] = _createParabolicSegment(boundary, boundary * 2);
    }

    /// @dev Two-segment curve: LINEAR then SIGMOID
    function _createLinearSigmoidSegments(
        uint256 boundary
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        segments = new Types.PiecewiseSegment[](2);
        segments[0] = _createLinearSegment(0, boundary);
        segments[1] = _createSigmoidSegment(boundary, boundary * 2);
    }

    /// @dev Three-segment curve: LINEAR → PARABOLIC → EXPONENTIAL
    function _createLinearParabolicExponentialSegments(
        uint256 boundary1,
        uint256 boundary2
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        segments = new Types.PiecewiseSegment[](3);
        segments[0] = _createLinearSegment(0, boundary1);
        segments[1] = _createParabolicSegment(boundary1, boundary2);
        segments[2] = _createExponentialSegment(boundary2, boundary2 + boundary1);
    }

    /// @dev Three-segment curve: LINEAR → LN → SIGMOID
    function _createLinearLnSigmoidSegments(
        uint256 boundary1,
        uint256 boundary2
    ) internal pure returns (Types.PiecewiseSegment[] memory segments) {
        segments = new Types.PiecewiseSegment[](3);
        segments[0] = _createLinearSegment(0, boundary1);
        segments[1] = _createLnSegment(boundary1, boundary2);
        segments[2] = _createSigmoidSegment(boundary2, boundary2 + boundary1);
    }
}
