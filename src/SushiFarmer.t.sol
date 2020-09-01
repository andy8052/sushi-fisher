pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./SushiFarmer.sol";

contract SushiFarmerTest is DSTest {
    SushiFarmer farmer;

    function setUp() public {
        farmer = new SushiFarmer();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
