// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Adapter8004} from "../src/Adapter8004.sol";
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
            adapter.register(Adapter8004.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/1", metadata);

        assertEq(registry.ownerOf(agentId), address(adapter));
        assertEq(registry.tokenURI(agentId), "ipfs://agent/1");
        assertEq(string(registry.getMetadata(agentId, "name")), "alpha");
        assertEq(registry.getAgentWallet(agentId), address(0));
        assertEq(
            registry.getMetadata(agentId, adapter.BINDING_METADATA_KEY()),
            adapter.encodeBindingMetadata(address(adapter), Adapter8004.TokenStandard.ERC721, address(token721), 1)
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
        adapter.register(Adapter8004.TokenStandard.ERC721, address(token721), 1, "", _emptyMetadata());
    }

    function testSameTokenCanRegisterMultipleAgents() external {
        uint256 firstAgentId = _register721(alice, 1);

        vm.prank(alice);
        uint256 secondAgentId =
            adapter.register(Adapter8004.TokenStandard.ERC721, address(token721), 1, "", _emptyMetadata());

        assertEq(firstAgentId, 0);
        assertEq(secondAgentId, 1);

        Adapter8004.Binding memory firstBinding = adapter.bindingOf(firstAgentId);
        Adapter8004.Binding memory secondBinding = adapter.bindingOf(secondAgentId);
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

    function testEncodeBindingMetadataUsesCompactTokenIdLengthByte() external view {
        bytes memory encoded =
            adapter.encodeBindingMetadata(address(adapter), Adapter8004.TokenStandard.ERC721, address(token721), 0x1234);
        bytes memory expected = abi.encodePacked(address(adapter), uint8(0), address(token721), uint8(2), hex"1234");
        assertEq(encoded, expected);
    }

    function testEncodeBindingMetadataEncodesZeroTokenIdWithZeroLength() external view {
        bytes memory encoded =
            adapter.encodeBindingMetadata(address(adapter), Adapter8004.TokenStandard.ERC721, address(token721), 0);
        bytes memory expected = abi.encodePacked(address(adapter), uint8(0), address(token721), uint8(0));
        assertEq(encoded, expected);
    }

    function testEncodeBindingMetadataUsesEnumByteFor1155() external view {
        bytes memory encoded =
            adapter.encodeBindingMetadata(address(adapter), Adapter8004.TokenStandard.ERC1155, address(token1155), 5);
        bytes memory expected = abi.encodePacked(address(adapter), uint8(1), address(token1155), uint8(1), hex"05");
        assertEq(encoded, expected);
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
        adapter.register(Adapter8004.TokenStandard.ERC721, address(token721), 1, "", metadata);
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

    function testAdminCanUpdateRegistryReference() external {
        vm.prank(admin);
        adapter.setIdentityRegistry(address(registry2));

        assertEq(address(adapter.identityRegistry()), address(registry2));

        vm.prank(alice);
        uint256 agentId = adapter.register(
            Adapter8004.TokenStandard.ERC721, address(token721), 1, "ipfs://agent/new", _emptyMetadata()
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
        return adapter.register(Adapter8004.TokenStandard.ERC721, address(token721), tokenId, "", _emptyMetadata());
    }

    function _register1155(address caller, uint256 tokenId) internal returns (uint256) {
        vm.prank(caller);
        return adapter.register(Adapter8004.TokenStandard.ERC1155, address(token1155), tokenId, "", _emptyMetadata());
    }

    function _register6909(address caller, uint256 tokenId) internal returns (uint256) {
        vm.prank(caller);
        return adapter.register(Adapter8004.TokenStandard.ERC6909, address(token6909), tokenId, "", _emptyMetadata());
    }

    function _emptyMetadata() internal pure returns (IERC8004IdentityRegistry.MetadataEntry[] memory metadata) {
        metadata = new IERC8004IdentityRegistry.MetadataEntry[](0);
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
