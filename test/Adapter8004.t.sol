// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Adapter8004} from "../src/Adapter8004.sol";
import {IERC8004AdapterCounterfactual} from "../src/interfaces/IERC8004AdapterCounterfactual.sol";
import {IERCAgentBindings} from "../src/interfaces/IERCAgentBindings.sol";
import {IERC8004IdentityRegistry} from "../src/interfaces/IERC8004IdentityRegistry.sol";
import {MockIdentityRegistry} from "./mocks/MockIdentityRegistry.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";
import {MockERC6909} from "./mocks/MockERC6909.sol";

contract Adapter8004Test is Test {
    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant AGENT_WALLET_SET_TYPEHASH =
        keccak256("AgentWalletSet(uint256 agentId,address newWallet,address owner,uint256 deadline)");

    MockIdentityRegistry internal registry;
    MockIdentityRegistry internal registry2;
    Adapter8004 internal adapter;
    MockERC721 internal token721;
    MockERC1155 internal token1155;
    MockERC6909 internal token6909;

    uint256 internal alicePk = 0xA11CE;
    uint256 internal bobPk = 0xB0B;
    uint256 internal walletPk = 0xCAFE;
    uint256 internal evePk = 0xE0E;

    address internal alice;
    address internal bob;
    address internal wallet;
    address internal eve;
    address internal admin;

    function setUp() external {
        alice = vm.addr(alicePk);
        bob = vm.addr(bobPk);
        wallet = vm.addr(walletPk);
        eve = vm.addr(evePk);
        admin = makeAddr("admin");

        registry = new MockIdentityRegistry();
        registry2 = new MockIdentityRegistry();

        Adapter8004 implementation = new Adapter8004();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(Adapter8004.initialize, (address(registry), admin))
        );
        adapter = Adapter8004(address(proxy));

        token721 = new MockERC721();
        token1155 = new MockERC1155();
        token6909 = new MockERC6909();

        token721.mint(alice, 1);
        token721.mint(bob, 2);
        token1155.mint(alice, 10, 5);
        token6909.mint(alice, 42, 3);
    }

    function testInitializeSetsAdminAndRegistry() external view {
        assertEq(adapter.owner(), admin);
        assertEq(address(adapter.identityRegistry()), address(registry));
    }

    function testRegisters721AndClearsInitialAdapterWallet() external {
        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](1);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "name", metadataValue: bytes("alpha")});

        vm.prank(alice);
        uint256 agentId =
            adapter.register(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/1", metadata);

        assertEq(registry.ownerOf(agentId), address(adapter));
        assertEq(registry.tokenURI(agentId), "ipfs://agent/1");
        assertEq(string(registry.getMetadata(agentId, "name")), "alpha");
        assertEq(registry.getAgentWallet(agentId), address(0));
        assertEq(registry.getMetadata(agentId, adapter.BINDING_METADATA_KEY()), abi.encodePacked(address(adapter)));

        assertEq(adapter.ownerOf(agentId), registry.ownerOf(agentId));
        assertEq(adapter.tokenURI(agentId), registry.tokenURI(agentId));
        assertEq(adapter.getMetadata(agentId, "name"), registry.getMetadata(agentId, "name"));
        assertEq(adapter.getAgentWallet(agentId), registry.getAgentWallet(agentId));
        assertEq(
            adapter.getMetadata(agentId, adapter.BINDING_METADATA_KEY()),
            registry.getMetadata(agentId, adapter.BINDING_METADATA_KEY())
        );
    }

    function test721ControllerCanUpdateRegistryFields() external {
        uint256 agentId = _register721(alice, 1);

        vm.startPrank(alice);
        adapter.setAgentURI(agentId, "ipfs://agent/updated");
        adapter.setMetadata(agentId, "description", bytes("new"));
        vm.stopPrank();

        assertEq(registry.tokenURI(agentId), "ipfs://agent/updated");
        assertEq(string(registry.getMetadata(agentId, "description")), "new");
    }

    function test721ControlFollowsTokenTransfer() external {
        uint256 agentId = _register721(alice, 1);

        vm.prank(alice);
        token721.transferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, alice, agentId));
        adapter.setMetadata(agentId, "x", bytes("1"));

        vm.prank(bob);
        adapter.setMetadata(agentId, "x", bytes("2"));

        assertEq(string(registry.getMetadata(agentId, "x")), "2");
    }

    function test1155ControlIsAnyCurrentHolder() external {
        uint256 agentId = _register1155(alice, 10);

        vm.prank(alice);
        token1155.safeTransferFrom(alice, bob, 10, 1, "");

        vm.prank(bob);
        adapter.setMetadata(agentId, "holder", bytes("bob"));

        assertEq(string(registry.getMetadata(agentId, "holder")), "bob");
    }

    function test6909ControlIsAnyCurrentHolder() external {
        uint256 agentId = _register6909(alice, 42);

        vm.prank(alice);
        token6909.transfer(bob, 42, 1);

        vm.prank(bob);
        adapter.setMetadata(agentId, "holder", bytes("bob"));

        assertEq(string(registry.getMetadata(agentId, "holder")), "bob");
    }

    function testCannotRegisterWithoutCurrentTokenControl() external {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.register(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "", _emptyMetadata());
    }

    function testRegisterNoMetadataOverloadProducesIdenticalBinding() external {
        vm.prank(alice);
        uint256 agentId =
            adapter.register(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/1");

        assertEq(registry.ownerOf(agentId), address(adapter));
        assertEq(registry.tokenURI(agentId), "ipfs://agent/1");
        assertEq(registry.getAgentWallet(agentId), address(0));
        assertEq(registry.getMetadata(agentId, adapter.BINDING_METADATA_KEY()), abi.encodePacked(address(adapter)));

        IERCAgentBindings.Binding memory binding = adapter.bindingOf(agentId);
        assertEq(uint8(binding.standard), uint8(IERCAgentBindings.TokenStandard.ERC721));
        assertEq(binding.tokenContract, address(token721));
        assertEq(binding.tokenId, 1);
    }

    function testRegisterNoMetadataOverloadEnforcesTokenControl() external {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.register(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "");
    }

    function testSameTokenCanRegisterMultipleAgents() external {
        uint256 firstAgentId = _register721(alice, 1);

        vm.prank(alice);
        uint256 secondAgentId =
            adapter.register(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "", _emptyMetadata());

        assertEq(firstAgentId, 0);
        assertEq(secondAgentId, 1);

        IERCAgentBindings.Binding memory firstBinding = adapter.bindingOf(firstAgentId);
        IERCAgentBindings.Binding memory secondBinding = adapter.bindingOf(secondAgentId);
        assertEq(firstBinding.tokenContract, address(token721));
        assertEq(secondBinding.tokenContract, address(token721));
        assertEq(firstBinding.tokenId, 1);
        assertEq(secondBinding.tokenId, 1);
    }

    function testSetMetadataBatch() external {
        uint256 agentId = _register721(alice, 1);

        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](2);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "a", metadataValue: bytes("1")});
        metadata[1] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "b", metadataValue: bytes("2")});

        vm.prank(alice);
        adapter.setMetadataBatch(agentId, metadata);

        assertEq(string(registry.getMetadata(agentId, "a")), "1");
        assertEq(string(registry.getMetadata(agentId, "b")), "2");
    }

    function testBindingMetadataEncodingIsTwentyByteAddress() external view {
        address binding = address(adapter);
        bytes memory encoded = abi.encodePacked(binding);
        assertEq(encoded.length, 20);
        assertEq(encoded, abi.encodePacked(binding));
    }

    function testBindingVerifierRoundTripUsesStoredBindingContract() external {
        uint256 agentId = _register721(alice, 1);

        bytes memory stored = registry.getMetadata(agentId, adapter.BINDING_METADATA_KEY());
        assertEq(stored.length, 20);

        address bindingContract = address(bytes20(stored));
        IERCAgentBindings.Binding memory binding = IERCAgentBindings(bindingContract).bindingOf(agentId);

        assertEq(uint256(binding.standard), uint256(IERCAgentBindings.TokenStandard.ERC721));
        assertEq(binding.tokenContract, address(token721));
        assertEq(binding.tokenId, 1);
    }

    function testAdapterImplementsIERCAgentBindingsInterface() external {
        uint256 agentId = _register721(alice, 1);

        IERCAgentBindings bindings = IERCAgentBindings(address(adapter));
        IERCAgentBindings.Binding memory binding = bindings.bindingOf(agentId);

        assertEq(uint256(binding.standard), uint256(IERCAgentBindings.TokenStandard.ERC721));
        assertEq(binding.tokenContract, address(token721));
        assertEq(binding.tokenId, 1);
    }

    function testRewriteBindingMetadataRewritesLegacyPayloadToTwentyBytes() external {
        uint256 agentId = _register721(alice, 1);
        string memory key = adapter.BINDING_METADATA_KEY();
        bytes memory legacy =
            _encodeLegacyBindingMetadata(address(adapter), IERCAgentBindings.TokenStandard.ERC721, address(token721), 1);
        assertGt(legacy.length, 20);

        vm.prank(address(adapter));
        registry.setMetadata(agentId, key, legacy);
        assertEq(registry.getMetadata(agentId, key), legacy);

        vm.prank(admin);
        adapter.rewriteBindingMetadata(agentId);

        bytes memory stored = registry.getMetadata(agentId, key);
        assertEq(stored.length, 20);
        assertEq(stored, abi.encodePacked(address(adapter)));
    }

    function testRegisterRejectsReservedBindingMetadataKey() external {
        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](1);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({
            metadataKey: adapter.BINDING_METADATA_KEY(),
            metadataValue: bytes("bad")
        });

        vm.expectRevert(
            abi.encodeWithSelector(Adapter8004.ReservedMetadataKey.selector, adapter.BINDING_METADATA_KEY())
        );
        vm.prank(alice);
        adapter.register(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "", metadata);
    }

    function testSetMetadataRejectsReservedBindingMetadataKey() external {
        uint256 agentId = _register721(alice, 1);
        string memory key = adapter.BINDING_METADATA_KEY();

        vm.expectRevert(abi.encodeWithSelector(Adapter8004.ReservedMetadataKey.selector, key));
        vm.prank(alice);
        adapter.setMetadata(agentId, key, bytes("bad"));
    }

    function testSetMetadataBatchRejectsReservedBindingMetadataKey() external {
        uint256 agentId = _register721(alice, 1);

        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](1);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({
            metadataKey: adapter.BINDING_METADATA_KEY(),
            metadataValue: bytes("bad")
        });

        vm.expectRevert(
            abi.encodeWithSelector(Adapter8004.ReservedMetadataKey.selector, adapter.BINDING_METADATA_KEY())
        );
        vm.prank(alice);
        adapter.setMetadataBatch(agentId, metadata);
    }

    function testSetAgentURIEmitsAdapterEvent() external {
        uint256 agentId = _register721(alice, 1);

        vm.recordLogs();
        vm.prank(alice);
        adapter.setAgentURI(agentId, "ipfs://agent/updated");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("AgentURISet(uint256,string,address)");
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(adapter) || logs[i].topics.length == 0) continue;
            if (logs[i].topics[0] == topic) {
                assertEq(logs[i].topics[1], bytes32(agentId));
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(alice))));
                assertEq(abi.decode(logs[i].data, (string)), "ipfs://agent/updated");
                ++matches;
            }
        }
        assertEq(matches, 1, "AgentURISet must fire exactly once from the adapter");
    }

    function testSetMetadataEmitsAdapterEvent() external {
        uint256 agentId = _register721(alice, 1);

        vm.recordLogs();
        vm.prank(alice);
        adapter.setMetadata(agentId, "description", bytes("hello"));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("MetadataSet(uint256,string,bytes,address)");
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(adapter) || logs[i].topics.length == 0) continue;
            if (logs[i].topics[0] == topic) {
                assertEq(logs[i].topics[1], bytes32(agentId));
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(alice))));
                (string memory key, bytes memory value) = abi.decode(logs[i].data, (string, bytes));
                assertEq(key, "description");
                assertEq(value, bytes("hello"));
                ++matches;
            }
        }
        assertEq(matches, 1, "MetadataSet must fire exactly once from the adapter");
    }

    function testSetAgentWalletEmitsAdapterEvent() external {
        uint256 agentId = _register721(alice, 1);
        uint256 deadline = block.timestamp + 4 minutes;
        bytes memory signature = _signAgentWallet(agentId, wallet, address(adapter), deadline, walletPk);

        vm.recordLogs();
        vm.prank(alice);
        adapter.setAgentWallet(agentId, wallet, deadline, signature);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("AgentWalletSet(uint256,address,address)");
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(adapter) || logs[i].topics.length == 0) continue;
            if (logs[i].topics[0] == topic) {
                assertEq(logs[i].topics[1], bytes32(agentId));
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(wallet))));
                assertEq(logs[i].topics[3], bytes32(uint256(uint160(alice))));
                ++matches;
            }
        }
        assertEq(matches, 1, "AgentWalletSet must fire exactly once from the adapter");
    }

    function testUnsetAgentWalletEmitsAdapterEvent() external {
        uint256 agentId = _register721(alice, 1);

        vm.recordLogs();
        vm.prank(alice);
        adapter.unsetAgentWallet(agentId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("AgentWalletUnset(uint256,address)");
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(adapter) || logs[i].topics.length == 0) continue;
            if (logs[i].topics[0] == topic) {
                assertEq(logs[i].topics[1], bytes32(agentId));
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(alice))));
                ++matches;
            }
        }
        assertEq(matches, 1, "AgentWalletUnset must fire exactly once from the adapter");
    }

    function testRewriteBindingMetadataEmitsAdapterEvent() external {
        uint256 agentId = _register721(alice, 1);

        vm.recordLogs();
        vm.prank(admin);
        adapter.rewriteBindingMetadata(agentId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("BindingMetadataRewritten(uint256,address)");
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(adapter) || logs[i].topics.length == 0) continue;
            if (logs[i].topics[0] == topic) {
                assertEq(logs[i].topics[1], bytes32(agentId));
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(admin))));
                ++matches;
            }
        }
        assertEq(matches, 1, "BindingMetadataRewritten must fire exactly once from the adapter");
    }

    function testSetAgentWalletPassesThroughNativeSignatureCheck() external {
        uint256 agentId = _register721(alice, 1);
        uint256 deadline = block.timestamp + 4 minutes;
        bytes memory signature = _signAgentWallet(agentId, wallet, address(adapter), deadline, walletPk);

        vm.prank(alice);
        adapter.setAgentWallet(agentId, wallet, deadline, signature);

        assertEq(registry.getAgentWallet(agentId), wallet);
    }

    function testSetAgentWalletRejectsInvalidSignature() external {
        uint256 agentId = _register721(alice, 1);
        uint256 deadline = block.timestamp + 4 minutes;
        bytes memory signature = _signAgentWallet(agentId, wallet, address(adapter), deadline, bobPk);

        vm.prank(alice);
        vm.expectRevert(bytes("invalid wallet sig"));
        adapter.setAgentWallet(agentId, wallet, deadline, signature);
    }

    function testCounterfactualRegisterEmitsEventAndReturnsHash() external {
        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](1);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "name", metadataValue: bytes("alpha")});

        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit IERC8004AdapterCounterfactual.CounterfactualAgentRegistered(
            expectedHash,
            address(token721),
            1,
            IERCAgentBindings.TokenStandard.ERC721,
            "ipfs://agent/cf",
            metadata,
            alice
        );
        bytes32 registrationHash = adapter.counterfactualRegister(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/cf", metadata
        );

        assertEq(registrationHash, expectedHash);
    }

    function testRegistrationHashViewMatchesEncodingAndCounterfactualEventTopic() external {
        bytes32 viewHash = adapter.registrationHash(address(token721), 1);
        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));
        assertEq(viewHash, expectedHash);

        vm.recordLogs();
        vm.prank(alice);
        bytes32 emittedHash =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://view");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(emittedHash, viewHash);
        assertEq(entries.length, 1);
        assertEq(entries[0].topics[0], IERC8004AdapterCounterfactual.CounterfactualAgentRegistered.selector);
        assertEq(entries[0].topics[1], viewHash);
    }

    function testCounterfactualRegisterEmptyMetadataOverload() external {
        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));

        vm.prank(alice);
        bytes32 registrationHash = adapter.counterfactualRegister(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/cf"
        );

        assertEq(registrationHash, expectedHash);
    }

    function testCounterfactualRegisterRejectsZeroTokenContract() external {
        vm.prank(alice);
        vm.expectRevert(Adapter8004.InvalidTokenContract.selector);
        adapter.counterfactualRegister(
            IERCAgentBindings.TokenStandard.ERC721, address(0), 1, "ipfs://agent/cf", _emptyMetadata()
        );
    }

    function testCounterfactualRegisterRejectsNonController() external {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.counterfactualRegister(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/cf", _emptyMetadata()
        );
    }

    function testCounterfactualRegisterRejectsReservedBindingMetadataKey() external {
        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](1);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({
            metadataKey: adapter.BINDING_METADATA_KEY(),
            metadataValue: bytes("bad")
        });

        vm.expectRevert(
            abi.encodeWithSelector(Adapter8004.ReservedMetadataKey.selector, adapter.BINDING_METADATA_KEY())
        );
        vm.prank(alice);
        adapter.counterfactualRegister(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/cf", metadata
        );
    }

    function testCounterfactualSetAgentURIEmits() external {
        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit IERC8004AdapterCounterfactual.CounterfactualAgentURISet(
            expectedHash, address(token721), 1, "ipfs://updated", alice
        );
        adapter.counterfactualSetAgentURI(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://updated"
        );
    }

    function testCounterfactualSetAgentURIRejectsZeroTokenContract() external {
        vm.prank(alice);
        vm.expectRevert(Adapter8004.InvalidTokenContract.selector);
        adapter.counterfactualSetAgentURI(IERCAgentBindings.TokenStandard.ERC721, address(0), 1, "ipfs://x");
    }

    function testCounterfactualSetAgentURIRejectsNonController() external {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.counterfactualSetAgentURI(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://x");
    }

    function testCounterfactualSetMetadataEmits() external {
        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit IERC8004AdapterCounterfactual.CounterfactualMetadataSet(
            expectedHash, address(token721), 1, "description", bytes("hello"), alice
        );
        adapter.counterfactualSetMetadata(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "description", bytes("hello")
        );
    }

    function testCounterfactualSetMetadataRejectsZeroTokenContract() external {
        vm.prank(alice);
        vm.expectRevert(Adapter8004.InvalidTokenContract.selector);
        adapter.counterfactualSetMetadata(IERCAgentBindings.TokenStandard.ERC721, address(0), 1, "k", bytes("v"));
    }

    function testCounterfactualSetMetadataRejectsNonController() external {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.counterfactualSetMetadata(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "k", bytes("v"));
    }

    function testCounterfactualSetMetadataRejectsReservedBindingMetadataKey() external {
        string memory key = adapter.BINDING_METADATA_KEY();

        vm.expectRevert(abi.encodeWithSelector(Adapter8004.ReservedMetadataKey.selector, key));
        vm.prank(alice);
        adapter.counterfactualSetMetadata(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, key, bytes("bad")
        );
    }

    function testCounterfactualSetMetadataBatchEmits() external {
        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));

        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](2);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "a", metadataValue: bytes("1")});
        metadata[1] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "b", metadataValue: bytes("2")});

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit IERC8004AdapterCounterfactual.CounterfactualMetadataBatchSet(
            expectedHash, address(token721), 1, metadata, alice
        );
        adapter.counterfactualSetMetadataBatch(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, metadata);
    }

    function testCounterfactualSetMetadataBatchRejectsZeroTokenContract() external {
        vm.prank(alice);
        vm.expectRevert(Adapter8004.InvalidTokenContract.selector);
        adapter.counterfactualSetMetadataBatch(IERCAgentBindings.TokenStandard.ERC721, address(0), 1, _emptyMetadata());
    }

    function testCounterfactualSetMetadataBatchRejectsNonController() external {
        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](1);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({metadataKey: "a", metadataValue: bytes("1")});

        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.counterfactualSetMetadataBatch(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, metadata);
    }

    function testCounterfactualSetMetadataBatchRejectsReservedBindingMetadataKey() external {
        IERC8004IdentityRegistry.MetadataEntry[] memory metadata = new IERC8004IdentityRegistry.MetadataEntry[](1);
        metadata[0] = IERC8004IdentityRegistry.MetadataEntry({
            metadataKey: adapter.BINDING_METADATA_KEY(),
            metadataValue: bytes("bad")
        });

        vm.expectRevert(
            abi.encodeWithSelector(Adapter8004.ReservedMetadataKey.selector, adapter.BINDING_METADATA_KEY())
        );
        vm.prank(alice);
        adapter.counterfactualSetMetadataBatch(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, metadata);
    }

    function testCounterfactualSetAgentWalletEmits() external {
        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit IERC8004AdapterCounterfactual.CounterfactualAgentWalletSet(
            expectedHash, address(token721), 1, wallet, alice
        );
        adapter.counterfactualSetAgentWallet(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, wallet);
    }

    function testCounterfactualSetAgentWalletRejectsZeroTokenContract() external {
        vm.prank(alice);
        vm.expectRevert(Adapter8004.InvalidTokenContract.selector);
        adapter.counterfactualSetAgentWallet(IERCAgentBindings.TokenStandard.ERC721, address(0), 1, wallet);
    }

    function testCounterfactualSetAgentWalletRejectsNonController() external {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.counterfactualSetAgentWallet(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, wallet);
    }

    function testCounterfactualUnsetAgentWalletEmits() external {
        bytes32 expectedHash = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true, address(adapter));
        emit IERC8004AdapterCounterfactual.CounterfactualAgentWalletUnset(expectedHash, address(token721), 1, alice);
        adapter.counterfactualUnsetAgentWallet(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1);
    }

    function testCounterfactualUnsetAgentWalletRejectsZeroTokenContract() external {
        vm.prank(alice);
        vm.expectRevert(Adapter8004.InvalidTokenContract.selector);
        adapter.counterfactualUnsetAgentWallet(IERCAgentBindings.TokenStandard.ERC721, address(0), 1);
    }

    function testCounterfactualUnsetAgentWalletRejectsNonController() external {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(Adapter8004.NotController.selector, eve, type(uint256).max));
        adapter.counterfactualUnsetAgentWallet(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1);
    }

    function testCounterfactualRegistrationHashIsStableForSameInputs() external {
        vm.prank(alice);
        bytes32 first =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "u1");

        vm.prank(alice);
        bytes32 second =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "u2");

        assertEq(first, second);
    }

    function testCounterfactualRegistrationHashChangesWithTokenContract() external {
        vm.prank(alice);
        bytes32 viaToken721 =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "u");
        vm.prank(alice);
        bytes32 viaToken1155 =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC1155, address(token1155), 10, "u");

        assertTrue(viaToken721 != viaToken1155);
    }

    function testCounterfactualRegistrationHashChangesWithTokenId() external {
        vm.prank(alice);
        bytes32 forId1 =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "u");
        vm.prank(bob);
        bytes32 forId2 =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 2, "u");

        assertTrue(forId1 != forId2);
    }

    function testCounterfactualRegistrationHashChangesWithChainId() external {
        bytes32 atDefaultChain = keccak256(abi.encode(block.chainid, address(adapter), address(token721), uint256(1)));
        bytes32 atOtherChain = keccak256(abi.encode(uint256(424242), address(adapter), address(token721), uint256(1)));

        assertTrue(atDefaultChain != atOtherChain);

        vm.chainId(424242);
        vm.prank(alice);
        bytes32 onAltChain =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "u");
        assertEq(onAltChain, atOtherChain);
    }

    function testCounterfactualRegistrationHashChangesWithAdapterAddress() external {
        Adapter8004 implementation = new Adapter8004();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(Adapter8004.initialize, (address(registry), admin))
        );
        Adapter8004 secondAdapter = Adapter8004(address(proxy));

        vm.prank(alice);
        bytes32 fromFirst =
            adapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "u");
        vm.prank(alice);
        bytes32 fromSecond =
            secondAdapter.counterfactualRegister(IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "u");

        assertTrue(fromFirst != fromSecond);
        assertTrue(address(adapter) != address(secondAdapter));
    }

    function testAdminCanUpdateRegistryReference() external {
        vm.prank(admin);
        adapter.setIdentityRegistry(address(registry2));

        assertEq(address(adapter.identityRegistry()), address(registry2));

        vm.prank(alice);
        uint256 agentId = adapter.register(
            IERCAgentBindings.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/new", _emptyMetadata()
        );

        assertEq(registry2.ownerOf(agentId), address(adapter));
        assertEq(registry2.tokenURI(agentId), "ipfs://agent/new");
    }

    function testNonAdminCannotUpdateRegistryReference() external {
        vm.prank(alice);
        vm.expectRevert();
        adapter.setIdentityRegistry(address(registry2));
    }

    function testAdminCanUpgradeImplementation() external {
        Adapter8004V2 nextImplementation = new Adapter8004V2();

        vm.prank(admin);
        adapter.upgradeToAndCall(address(nextImplementation), bytes(""));

        assertEq(Adapter8004V2(address(adapter)).version(), "2");
        assertEq(address(adapter.identityRegistry()), address(registry));
        assertEq(adapter.owner(), admin);
    }

    function testNonAdminCannotUpgradeImplementation() external {
        Adapter8004V2 nextImplementation = new Adapter8004V2();

        vm.prank(alice);
        vm.expectRevert();
        adapter.upgradeToAndCall(address(nextImplementation), bytes(""));
    }

    function _register721(address caller, uint256 tokenId) internal returns (uint256) {
        vm.prank(caller);
        return
            adapter.register(IERCAgentBindings.TokenStandard.ERC721, address(token721), tokenId, "", _emptyMetadata());
    }

    function _register1155(address caller, uint256 tokenId) internal returns (uint256) {
        vm.prank(caller);
        return
            adapter.register(IERCAgentBindings.TokenStandard.ERC1155, address(token1155), tokenId, "", _emptyMetadata());
    }

    function _register6909(address caller, uint256 tokenId) internal returns (uint256) {
        vm.prank(caller);
        return
            adapter.register(IERCAgentBindings.TokenStandard.ERC6909, address(token6909), tokenId, "", _emptyMetadata());
    }

    function _emptyMetadata() internal pure returns (IERC8004IdentityRegistry.MetadataEntry[] memory metadata) {
        metadata = new IERC8004IdentityRegistry.MetadataEntry[](0);
    }

    function _encodeLegacyBindingMetadata(
        address bindingContract,
        IERCAgentBindings.TokenStandard standard,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (bytes memory) {
        bytes memory compactTokenId = _encodeCompactUint(tokenId);
        return abi.encodePacked(
            bindingContract, uint8(standard), tokenContract, uint8(compactTokenId.length), compactTokenId
        );
    }

    function _encodeCompactUint(uint256 value) internal pure returns (bytes memory out) {
        if (value == 0) {
            return bytes("");
        }

        uint256 temp = value;
        uint256 length;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }

        out = new bytes(length);
        temp = value;
        for (uint256 i = length; i > 0; --i) {
            out[i - 1] = bytes1(uint8(temp));
            temp >>= 8;
        }
    }

    function _signAgentWallet(uint256 agentId, address newWallet, address owner, uint256 deadline, uint256 signerPk)
        internal
        view
        returns (bytes memory)
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("ERC8004IdentityRegistry")),
                keccak256(bytes("1")),
                block.chainid,
                address(registry)
            )
        );

        bytes32 structHash = keccak256(abi.encode(AGENT_WALLET_SET_TYPEHASH, agentId, newWallet, owner, deadline));
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }
}

contract Adapter8004V2 is Adapter8004 {
    function version() external pure returns (string memory) {
        return "2";
    }
}
