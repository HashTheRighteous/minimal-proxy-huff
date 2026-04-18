/*//////////////////////////////////////////////////////////////
                            VERSION
//////////////////////////////////////////////////////////////*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/
import {Test, console} from "forge-std/Test.sol";
import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";

/*//////////////////////////////////////////////////////////////
                          TEST CONTRACT
//////////////////////////////////////////////////////////////*/
contract MinimalProxyFactoryTest is Test {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address proxy;
    address implementation;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        // Deploy a dummy implementation contract
        implementation = address(new DummyImplementation());
        // Deploy the Huff proxy directly (the constructor returns the proxy bytecode)
        proxy = HuffDeployer.config().with_args(abi.encode(implementation)).deploy("MinimalProxyFactory");
    }

    /*//////////////////////////////////////////////////////////////
                              UNIT TESTS
    //////////////////////////////////////////////////////////////*/
    function testProxyDeploymentAndDelegateCall() public {
        // Verify the proxy's bytecode exists
        bytes memory proxyCode = address(proxy).code;
        assertTrue(proxyCode.length > 0, "Proxy has no code");

        // Call setValue(42) on the proxy via delegatecall
        (bool success,) = proxy.call(abi.encodeWithSignature("setValue(uint256)", 42));
        require(success, "Proxy delegatecall failed");

        // Verify that the implementation's storage slot 0 is still 0
        uint256 implValue = uint256(vm.load(implementation, bytes32(uint256(0))));
        assertEq(implValue, 0, "Implementation storage should be untouched");

        // Verify that the proxy's storage slot 0 now contains 42
        uint256 proxyValue = uint256(vm.load(proxy, bytes32(uint256(0))));
        assertEq(proxyValue, 42, "Proxy storage should be updated via delegatecall");
    }

    /*//////////////////////////////////////////////////////////////
                         REVERT BUBBLING UNIT
    //////////////////////////////////////////////////////////////*/
    function testRevertBubbling() public {
        address revertImpl = address(new RevertingImplementation());
        address revertProxy = HuffDeployer.config().with_args(abi.encode(revertImpl)).deploy("MinimalProxyFactory");

        (bool success, bytes memory result) =
            revertProxy.call(abi.encodeWithSignature("causeRevert(bytes32)", bytes32("test revert")));

        assertTrue(!success, "Proxy should revert when implementation reverts");
        assertTrue(result.length > 0, "Revert data should be forwarded");
    }

    /*//////////////////////////////////////////////////////////////
       	              RETURN DATA FORWARDING UNIT
    //////////////////////////////////////////////////////////////*/
    function testReturnDataForwarding() public {
        address returnImpl = address(new ReturnDataImplementation());
        address returnProxy = HuffDeployer.config().with_args(abi.encode(returnImpl)).deploy("MinimalProxyFactory");

        (bool success, bytes memory result) = returnProxy.call(
            abi.encodeWithSignature(
                "returnComplexData(uint256,address,bytes32)", 12345, address(this), bytes32("test return data")
            )
        );
        require(success, "Proxy call failed");

        ReturnDataImplementation.TestStruct memory decoded = abi.decode(result, (ReturnDataImplementation.TestStruct));

        assertEq(decoded.value, 12345, "Value should be forwarded correctly");
        assertEq(decoded.sender, address(this), "Sender should be the test contract");
        assertEq(decoded.message, bytes32("test return data"), "Message should be forwarded correctly");
    }

    /*//////////////////////////////////////////////////////////////
                       MSG.VALUE FORWARDING UNIT
    //////////////////////////////////////////////////////////////*/
    function testMsgValueForwarding() public {
        // Deploy payable implementation
        address payableImpl = address(new PayableImplementation());
        // Deploy proxy pointing to this implementation
        address payableProxy = HuffDeployer.config().with_args(abi.encode(payableImpl)).deploy("MinimalProxyFactory");

        // Give the test contract some ETH
        vm.deal(address(this), 1 ether);

        // Call the payable function through the proxy, sending 1 ether
        (bool success,) = payableProxy.call{value: 1 ether}(abi.encodeWithSignature("receiveEth()"));
        require(success, "Proxy payable call failed");

        // Verify the proxy's balance increased
        assertEq(address(payableProxy).balance, 1 ether, "Proxy should hold the ETH");

        // Verify the implementation recorded the msg.value correctly (in the proxy's storage slot 0)
        uint256 proxyRecordedValue = uint256(vm.load(payableProxy, bytes32(uint256(0))));
        assertEq(proxyRecordedValue, 1 ether, "Proxy storage should record msg.value");
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    function testProxyDeploymentAndDelegateCallFuzz(uint256 amount) public {
        // Verify the proxy's bytecode exists
        bytes memory proxyCode = address(proxy).code;
        assertTrue(proxyCode.length > 0, "Proxy has no code");

        // Call setValue(42) on the proxy via delegatecall
        (bool success,) = proxy.call(abi.encodeWithSignature("setValue(uint256)", uint256(amount)));
        require(success, "Proxy delegatecall failed");

        // Verify that the implementation's storage slot 0 is still 0
        uint256 implValue = uint256(vm.load(implementation, bytes32(uint256(0))));
        assertEq(implValue, 0, "Implementation storage should be untouched");

        // Verify that the proxy's storage slot 0 now contains 42
        uint256 proxyValue = uint256(vm.load(proxy, bytes32(uint256(0))));
        assertEq(proxyValue, uint256(amount), "Proxy storage should be updated via delegatecall");
    }

    /*//////////////////////////////////////////////////////////////
                         REVERT BUBBLING FUZZ
    //////////////////////////////////////////////////////////////*/
    function testRevertBubblingFuzz(bytes32 errorMessage) public {
        address revertImpl = address(new RevertingImplementation());
        address revertProxy = HuffDeployer.config().with_args(abi.encode(revertImpl)).deploy("MinimalProxyFactory");

        (bool success, bytes memory result) =
            revertProxy.call(abi.encodeWithSignature("causeRevert(bytes32)", errorMessage));

        assertTrue(!success, "Proxy should revert when implementation reverts");
        assertTrue(result.length > 0, "Revert data should be forwarded");
    }

    /*//////////////////////////////////////////////////////////////
       	              RETURN DATA FORWARDING FUZZ
    //////////////////////////////////////////////////////////////*/
    function testReturnDataForwardingFuzz(uint256 val, address sender, bytes32 message) public {
        address returnImpl = address(new ReturnDataImplementation());
        address returnProxy = HuffDeployer.config().with_args(abi.encode(returnImpl)).deploy("MinimalProxyFactory");

        (bool success, bytes memory result) = returnProxy.call(
            abi.encodeWithSignature("returnComplexData(uint256,address,bytes32)", val, sender, message)
        );
        require(success, "Proxy call failed");

        ReturnDataImplementation.TestStruct memory decoded = abi.decode(result, (ReturnDataImplementation.TestStruct));

        assertEq(decoded.value, val, "Value should be forwarded correctly");
        assertEq(decoded.sender, sender, "Sender should be the test contract");
        assertEq(decoded.message, message, "Message should be forwarded correctly");
    }

    /*//////////////////////////////////////////////////////////////
                       MSG.VALUE FORWARDING FUZZ
    //////////////////////////////////////////////////////////////*/
    function testMsgValueForwardingFuzz(uint256 amount) public {
        vm.assume(amount < type(uint128).max); // Prevent overflow with deal

        address payableImpl = address(new PayableImplementation());
        address payableProxy = HuffDeployer.config().with_args(abi.encode(payableImpl)).deploy("MinimalProxyFactory");

        vm.deal(address(this), amount);

        (bool success,) = payableProxy.call{value: amount}(abi.encodeWithSignature("receiveEth()"));
        require(success, "Proxy payable call failed");

        assertEq(address(payableProxy).balance, amount, "Proxy should hold the ETH");
        uint256 proxyRecordedValue = uint256(vm.load(payableProxy, bytes32(uint256(0))));
        assertEq(proxyRecordedValue, amount, "Proxy storage should record msg.value");
    }

    /*//////////////////////////////////////////////////////////////
                          GAS BENCHMARK TEST
    //////////////////////////////////////////////////////////////*/
    function testGasBenchmarkFuzz() public {
        address ozFactory = address(new EIP1167Factory());
        address ozProxy = EIP1167Factory(ozFactory).clone(implementation);
        address huffProxy = HuffDeployer.config().with_args(abi.encode(implementation)).deploy("MinimalProxyFactory");

        uint256 gasBeforeOZ = gasleft();
        (bool successOZ,) = ozProxy.call(abi.encodeWithSignature("setValue(uint256)", 42));
        uint256 gasUsedOZ = gasBeforeOZ - gasleft();
        require(successOZ, "OZ call failed");

        uint256 gasBeforeHuff = gasleft();
        (bool successHuff,) = huffProxy.call(abi.encodeWithSignature("setValue(uint256)", 42));
        uint256 gasUsedHuff = gasBeforeHuff - gasleft();
        require(successHuff, "Huff call failed");

        console.log("Standard EIP-1167 Proxy Gas: ", gasUsedOZ);
        console.log("Your Huff Bare-Metal Gas: ", gasUsedHuff);
    }

    /*//////////////////////////////////////////////////////////////
                            FV TESTS
    //////////////////////////////////////////////////////////////*/
    function check_ProxyDeploymentAndDelegateCall(uint256 amount) public {
        bytes memory proxyCode = address(proxy).code;
        assert(proxyCode.length > 0);

        (bool success,) = proxy.call(abi.encodeWithSignature("setValue(uint256)", amount));
        assert(success);

        uint256 implValue = uint256(vm.load(implementation, bytes32(uint256(0))));
        assert(implValue == 0);

        uint256 proxyValue = uint256(vm.load(proxy, bytes32(uint256(0))));
        assert(proxyValue == amount);
    }

    /*//////////////////////////////////////////////////////////////
                       	 REVERT BUBBLING FV
    //////////////////////////////////////////////////////////////*/
    function check_RevertBubbling(bytes32 errorMessage) public {
        address revertImpl = address(new RevertingImplementation());
        address revertProxy = HuffDeployer.config().with_args(abi.encode(revertImpl)).deploy("MinimalProxyFactory");

        (bool success, bytes memory result) =
            revertProxy.call(abi.encodeWithSignature("causeRevert(bytes32)", errorMessage));

        assert(!success);
        assert(result.length > 0);
    }

    /*//////////////////////////////////////////////////////////////
       	              RETURN DATA FORWARDING FV
    //////////////////////////////////////////////////////////////*/
    function check_ReturnDataForwarding(uint256 val, address sender, bytes32 message) public {
        address returnImpl = address(new ReturnDataImplementation());
        address returnProxy = HuffDeployer.config().with_args(abi.encode(returnImpl)).deploy("MinimalProxyFactory");

        (bool success, bytes memory result) = returnProxy.call(
            abi.encodeWithSignature("returnComplexData(uint256,address,bytes32)", val, sender, message)
        );
        assert(success);

        ReturnDataImplementation.TestStruct memory decoded = abi.decode(result, (ReturnDataImplementation.TestStruct));

        assert(decoded.value == val);
        assert(decoded.sender == sender);
        assert(decoded.message == message);
    }

    /*//////////////////////////////////////////////////////////////
                      MSG.VALUE FORWARDING FV
    //////////////////////////////////////////////////////////////*/
    function check_MsgValueForwarding(uint256 amount) public {
        vm.assume(amount < type(uint128).max);

        address payableImpl = address(new PayableImplementation());
        address payableProxy = HuffDeployer.config().with_args(abi.encode(payableImpl)).deploy("MinimalProxyFactory");

        vm.deal(address(this), amount);

        (bool success,) = payableProxy.call{value: amount}(abi.encodeWithSignature("receiveEth()"));
        assert(success);

        assert(address(payableProxy).balance == amount);
        uint256 proxyRecordedValue = uint256(vm.load(payableProxy, bytes32(uint256(0))));
        assert(proxyRecordedValue == amount);
    }
}

/*//////////////////////////////////////////////////////////////
                        LOGIC CONTRACTS
//////////////////////////////////////////////////////////////*/
contract DummyImplementation {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract RevertingImplementation {
    error CustomError(bytes32 message);

    function causeRevert(bytes32 message) external pure {
        revert CustomError(message);
    }
}

contract ReturnDataImplementation {
    struct TestStruct {
        uint256 value;
        address sender;
        bytes32 message;
    }

    function returnComplexData(uint256 val, address sender, bytes32 msgStr) external pure returns (TestStruct memory) {
        return TestStruct({value: val, sender: sender, message: msgStr});
    }
}

contract PayableImplementation {
    uint256 public lastValueReceived;

    function receiveEth() external payable {
        lastValueReceived = msg.value;
    }
}

/*//////////////////////////////////////////////////////////////
                    ORIGINAL EIP1167FACTORY
//////////////////////////////////////////////////////////////*/
contract EIP1167Factory {
    function clone(address implementation) external returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
    }
}
