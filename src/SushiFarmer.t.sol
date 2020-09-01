pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./SushiFarmer.sol";

contract SushiFisherTest is DSTest {
    SushiFisher fisher;

    function setUp() public {
        fisher = new SushiFisher(address(0), 0);
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
